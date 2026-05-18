#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
require 'json'
require 'rack/mock'

ENV['RAILS_ENV'] ||= 'test'
ENV.delete('HTTP_PROXY')

require_relative '../spec/dummy/config/environment'

module SmokePlunkUnsubscribeWebhook
  module_function

  Scenario = Struct.new(:name, :verify, keyword_init: true)

  def run!
    ensure_dummy_app!
    reset_replay_cache!

    scenarios = [
      Scenario.new(
        name: 'disabled',
        verify: method(:verify_disabled_scenario)
      ),
      Scenario.new(
        name: 'unauthorized',
        verify: method(:verify_unauthorized_scenario)
      ),
      Scenario.new(
        name: 'success',
        verify: method(:verify_success_scenario)
      ),
      Scenario.new(
        name: 'invalid_json',
        verify: method(:verify_invalid_json_scenario)
      )
    ]

    failures = scenarios.filter_map do |scenario|
      reset_replay_cache!
      integration = build_integration
      scenario.verify.call(integration)
    end.compact

    puts
    if failures.empty?
      puts 'Smoke check passed: Plunk unsubscribe webhook scenarios behaved as expected.'
    else
      warn 'Smoke check failed:'
      failures.each { |failure| warn "  - #{failure}" }
      exit 1
    end
  end

  def ensure_dummy_app!
    dummy_app_path = File.expand_path('../spec/dummy/config/environment.rb', __dir__)
    return if File.exist?(dummy_app_path)

    abort 'Missing spec/dummy. Run `SPREE_PATH=ref/spree/spree bundle exec rake test_app` first.'
  end

  def reset_replay_cache!
    Rails.cache.clear
    SpreePlunk::ProcessUnsubscribeWebhook.replay_cache_store.clear
  end

  def build_integration
    integration = Spree::Integrations::Plunk.find_or_initialize_by(store: smoke_store)
    integration.assign_attributes(
      active: true,
      preferred_plunk_base_url: 'https://next-api.useplunk.com',
      preferred_plunk_secret_api_key: 'sk_smoke',
      preferred_unsubscribe_webhook_enabled: true,
      preferred_unsubscribe_webhook_authorization_token: 'whsec_smoke'
    )
    integration.save!
    integration
  end

  def smoke_store
    @smoke_store ||= Spree::Store.find_or_create_by!(code: 'plunk-webhook-smoke') do |store|
      store.name = 'Plunk Webhook Smoke'
      store.url = 'plunk-webhook-smoke.test'
      store.mail_from_address = 'smoke@example.com'
      store.default = false
    end
  end

  def webhook_path(integration)
    Spree::Core::Engine.routes.url_helpers.plunk_unsubscribe_webhook_path(integration)
  end

  def authorization_for(integration, scenario_name)
    token =
      case scenario_name
      when 'unauthorized'
        'wrong-token'
      else
        integration.preferred_unsubscribe_webhook_authorization_token
      end

    "Bearer #{token}"
  end

  def unsubscribe_payload(email, execution_id:)
    JSON.generate(
      contact: {
        email: email,
        subscribed: false
      },
      execution: {
        id: execution_id
      },
      workflow: {
        id: 'wf_smoke',
        name: 'Smoke Unsubscribe Flow'
      },
      event: {
        name: 'contact.unsubscribed'
      }
    )
  end

  def deliver_request(path:, authorization:, body:)
    Rack::MockRequest.new(Rails.application).post(
      path,
      'CONTENT_TYPE' => 'application/json',
      'HTTP_AUTHORIZATION' => authorization,
      input: body
    )
  end

  def verify_disabled_scenario(integration)
    integration.update!(
      preferred_unsubscribe_webhook_enabled: false,
      preferred_unsubscribe_webhook_authorization_token: nil
    )

    disabled_response = deliver_request(
      path: webhook_path(integration),
      authorization: 'Bearer whsec_smoke',
      body: unsubscribe_payload('disabled@example.com', execution_id: 'exec-disabled')
    )

    puts "[disabled] status=#{disabled_response.status}"

    return nil if disabled_response.status == 404

    "disabled: expected status 404, got #{disabled_response.status}"
  end

  def verify_unauthorized_scenario(integration)
    response = deliver_request(
      path: webhook_path(integration),
      authorization: authorization_for(integration, 'unauthorized'),
      body: unsubscribe_payload('unauthorized@example.com', execution_id: 'exec-unauthorized')
    )

    puts "[unauthorized] status=#{response.status}"

    return nil if response.status == 401

    "unauthorized: expected status 401, got #{response.status}"
  end

  def verify_success_scenario(integration)
    user = create_user(email: 'success@example.com')
    subscriber = create_subscriber(email: user.email, user: user)

    response = deliver_request(
      path: webhook_path(integration),
      authorization: authorization_for(integration, 'success'),
      body: unsubscribe_payload(subscriber.email, execution_id: 'exec-success-seeded')
    )

    duplicate_response = deliver_request(
      path: webhook_path(integration),
      authorization: authorization_for(integration, 'success'),
      body: unsubscribe_payload(subscriber.email, execution_id: 'exec-success-seeded')
    )

    replay_key = SpreePlunk::ProcessUnsubscribeWebhook.new.send(
      :replay_cache_key,
      plunk_integration: integration,
      payload: {
        'contact' => { 'email' => subscriber.email, 'subscribed' => false },
        'execution' => { 'id' => 'exec-success-seeded' },
        'workflow' => { 'id' => 'wf_smoke', 'name' => 'Smoke Unsubscribe Flow' },
        'event' => { 'name' => 'contact.unsubscribed' }
      }
    )

    puts "[success] first_status=#{response.status} duplicate_status=#{duplicate_response.status} " \
         "subscriber_present=#{Spree::NewsletterSubscriber.exists?(id: subscriber.id)} " \
         "user_accepts_marketing=#{user.reload.accepts_email_marketing} " \
         "replay_claimed=#{SpreePlunk::ProcessUnsubscribeWebhook.replay_cache_store.exist?(replay_key)}"

    return nil if response.status == 200 &&
                 duplicate_response.status == 200 &&
                 !Spree::NewsletterSubscriber.exists?(id: subscriber.id) &&
                 user.reload.accepts_email_marketing == false &&
                 SpreePlunk::ProcessUnsubscribeWebhook.replay_cache_store.exist?(replay_key)

    'success: expected 200/200 with subscriber removed, user marketing cleared, and replay claim recorded'
  end

  def verify_invalid_json_scenario(integration)
    response = deliver_request(
      path: webhook_path(integration),
      authorization: authorization_for(integration, 'invalid_json'),
      body: '{"contact":'
    )

    puts "[invalid_json] status=#{response.status}"

    return nil if response.status == 400

    "invalid_json: expected status 400, got #{response.status}"
  end

  def create_user(email:)
    Spree.user_class.find_or_create_by!(email: email) do |user|
      user.password = 'Password123!'
      user.password_confirmation = 'Password123!'
      user.accepts_email_marketing = true if user.respond_to?(:accepts_email_marketing=)
    end.tap do |user|
      user.update!(accepts_email_marketing: true) if user.respond_to?(:accepts_email_marketing=)
    end
  end

  def create_subscriber(email:, user:)
    Spree::NewsletterSubscriber.find_or_create_by!(email: email) do |subscriber|
      subscriber.user = user
      subscriber.verified_at = Time.current
      subscriber.verification_token = nil
    end.tap do |subscriber|
      subscriber.update!(user: user, verified_at: Time.current, verification_token: nil)
    end
  end
end

SmokePlunkUnsubscribeWebhook.run!
