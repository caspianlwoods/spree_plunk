module SpreePlunk
  class UpsertContact < Base
    prepend ::Spree::ServiceModule::Base

    def call(plunk_integration:, user: nil, subscriber: nil, address: nil, email: nil, subscribed: nil)
      payload = ContactPresenter.new(
        user: user,
        subscriber: subscriber,
        address: address,
        email: email,
        store: plunk_integration.store
      ).call(subscribed: resolved_subscription_state(user: user, subscriber: subscriber, subscribed: subscribed))

      return noop_result('missing_email') if payload[:email].blank?

      plunk_integration.upsert_contact(payload)
    end

    private

    def resolved_subscription_state(user:, subscriber:, subscribed:)
      return subscribed unless subscribed.nil?

      false
    end
  end
end
