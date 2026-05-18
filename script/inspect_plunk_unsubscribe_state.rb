#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'

ENV['RAILS_ENV'] ||= 'test'
ENV.delete('HTTP_PROXY')

require_relative '../spec/dummy/config/environment'

module InspectPlunkUnsubscribeState
  module_function

  def run!
    email = ENV.fetch('EMAIL').strip.downcase

    subscriber = Spree::NewsletterSubscriber.find_by(email: email)
    user = Spree.user_class.find_by(email: email)

    puts <<~OUTPUT

      Local unsubscribe state for #{email}

      newsletter_subscriber_present: #{subscriber.present?}
      newsletter_subscriber_id: #{subscriber&.id.inspect}
      newsletter_verified_at: #{subscriber&.verified_at.inspect}
      user_present: #{user.present?}
      user_id: #{user&.id.inspect}
      user_accepts_email_marketing: #{user&.accepts_email_marketing.inspect}
    OUTPUT
  rescue KeyError
    abort 'Missing EMAIL. Example: `EMAIL=user@example.com SPREE_PATH=ref/spree/spree bundle exec ruby script/inspect_plunk_unsubscribe_state.rb`'
  end
end

InspectPlunkUnsubscribeState.run!
