#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
require 'securerandom'

ENV['RAILS_ENV'] ||= 'test'
ENV.delete('HTTP_PROXY')

require_relative '../spec/dummy/config/environment'

module PreparePlunkUnsubscribeWebhookLiveCheck
  module_function

  REQUIRED_PUBLIC_URL_SCHEME = /\Ahttps?:\/\//i

  def run!
    ensure_dummy_app!

    integration = build_integration!
    user = seed_user!(email: test_email)
    subscriber = seed_subscriber!(email: test_email, user: user)
    connectivity_result = check_connectivity(integration)

    puts <<~OUTPUT

      Plunk unsubscribe webhook live-check assets are ready.

      Store:
        code: #{integration.store.code}
        id: #{integration.store.id}

      Integration:
        id: #{integration.id}
        param: #{integration.to_param}
        active: #{integration.active?}
        plunk_base_url: #{integration.preferred_plunk_base_url}
        unsubscribe_webhook_enabled: #{integration.preferred_unsubscribe_webhook_enabled}

      Webhook endpoint:
        route_path: #{webhook_path(integration)}
        public_url: #{public_webhook_url(integration)}
        authorization_header: Bearer #{integration.preferred_unsubscribe_webhook_authorization_token}

      Test contact:
        email: #{subscriber.email}
        newsletter_subscriber_id: #{subscriber.id}
        user_id: #{user.id}
        user_accepts_email_marketing: #{user.accepts_email_marketing.inspect}

      Connectivity:
        #{connectivity_result}

      Plunk workflow checklist:
        1. In Plunk, create or update a workflow triggered by `contact.unsubscribed`.
        2. Add a Webhook step that sends POST #{public_webhook_url(integration)}.
        3. Set header `Authorization: Bearer #{integration.preferred_unsubscribe_webhook_authorization_token}`.
        4. Leave the body empty to use Plunk's default webhook payload, or send a payload that still includes unsubscribe semantics plus the contact email.
        5. Unsubscribe #{subscriber.email} in Plunk.
        6. Verify locally that the newsletter subscriber row is removed and the user marketing flag is false:
           `EMAIL=#{subscriber.email} SPREE_PATH=ref/spree/spree bundle exec ruby script/inspect_plunk_unsubscribe_state.rb`

      Expected local outcome after a successful Plunk webhook:
        - `Spree::NewsletterSubscriber.find_by(email: #{subscriber.email.inspect})` returns nil
        - `Spree.user_class.find_by(email: #{subscriber.email.inspect})&.accepts_email_marketing` returns false
        - Re-sending the exact same webhook delivery should remain 200 and be ignored by replay protection
    OUTPUT
  end

  def ensure_dummy_app!
    dummy_app_path = File.expand_path('../spec/dummy/config/environment.rb', __dir__)
    return if File.exist?(dummy_app_path)

    abort 'Missing spec/dummy. Run `SPREE_PATH=ref/spree/spree bundle exec rake test_app` first.'
  end

  def build_integration!
    integration = Spree::Integrations::Plunk.find_or_initialize_by(store: live_check_store)
    integration.assign_attributes(
      active: true,
      preferred_plunk_base_url: plunk_base_url,
      preferred_plunk_secret_api_key: plunk_secret_api_key,
      preferred_unsubscribe_webhook_enabled: true,
      preferred_unsubscribe_webhook_authorization_token: webhook_token
    )
    integration.save!
    integration
  end

  def live_check_store
    @live_check_store ||= Spree::Store.find_or_create_by!(code: 'plunk-live-check') do |store|
      store.name = 'Plunk Live Check'
      store.url = local_store_host
      store.mail_from_address = 'plunk-live-check@example.com'
      store.default = false
    end.tap do |store|
      store.update!(url: local_store_host) if store.url != local_store_host
    end
  end

  def seed_user!(email:)
    Spree.user_class.find_or_create_by!(email: email) do |user|
      user.password = 'Password123!'
      user.password_confirmation = 'Password123!'
      user.accepts_email_marketing = true if user.respond_to?(:accepts_email_marketing=)
    end.tap do |user|
      user.update!(accepts_email_marketing: true) if user.respond_to?(:accepts_email_marketing=)
    end
  end

  def seed_subscriber!(email:, user:)
    Spree::NewsletterSubscriber.find_or_create_by!(email: email) do |subscriber|
      subscriber.user = user
      subscriber.verified_at = Time.current
      subscriber.verification_token = nil
    end.tap do |subscriber|
      subscriber.update!(user: user, verified_at: Time.current, verification_token: nil)
    end
  end

  def check_connectivity(integration)
    return 'skipped (set PLUNK_LIVE_CHECK_CONNECTIVITY=true to test the configured base URL and secret key)' unless connectivity_check_enabled?

    integration.can_connect? ? 'success' : "failed: #{integration.connection_error_message}"
  rescue StandardError => e
    "failed with #{e.class}: #{e.message}"
  end

  def connectivity_check_enabled?
    ActiveModel::Type::Boolean.new.cast(ENV['PLUNK_LIVE_CHECK_CONNECTIVITY'])
  end

  def webhook_path(integration)
    Spree::Core::Engine.routes.url_helpers.plunk_unsubscribe_webhook_path(integration)
  end

  def public_webhook_url(integration)
    "#{public_base_url}#{webhook_path(integration)}"
  end

  def public_base_url
    value = ENV['PLUNK_LIVE_WEBHOOK_BASE_URL'].to_s.strip
    return value.sub(%r{/*\z}, '') if value.match?(REQUIRED_PUBLIC_URL_SCHEME)

    "http://#{local_store_host}:#{local_port}"
  end

  def local_store_host
    ENV.fetch('PLUNK_LIVE_LOCAL_HOST', 'localhost')
  end

  def local_port
    ENV.fetch('PLUNK_LIVE_LOCAL_PORT', '3000')
  end

  def plunk_base_url
    ENV.fetch('PLUNK_LIVE_BASE_URL', 'https://next-api.useplunk.com')
  end

  def plunk_secret_api_key
    ENV.fetch('PLUNK_LIVE_SECRET_API_KEY', 'sk_live_placeholder')
  end

  def webhook_token
    ENV['PLUNK_LIVE_WEBHOOK_TOKEN'].presence || generated_webhook_token
  end

  def generated_webhook_token
    @generated_webhook_token ||= "whsec_live_check_#{SecureRandom.hex(12)}"
  end

  def test_email
    ENV.fetch('EMAIL', 'plunk-live-check@example.com').strip.downcase
  end
end

PreparePlunkUnsubscribeWebhookLiveCheck.run!
