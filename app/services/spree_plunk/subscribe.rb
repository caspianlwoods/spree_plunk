module SpreePlunk
  class Subscribe < Base
    prepend ::Spree::ServiceModule::Base

    def call(plunk_integration:, subscriber:)
      payload = build_payload(
        plunk_integration: plunk_integration,
        subscriber: subscriber,
        subscribed: true
      )
      return noop_result('missing_email') if payload.nil?

      plunk_integration.subscribe_contact(payload)
    end

    private

    def build_payload(plunk_integration:, subscriber:, subscribed:)
      payload = ContactPresenter.new(
        subscriber: subscriber,
        store: plunk_integration.store
      ).call(subscribed: subscribed)

      payload[:email].present? ? payload : nil
    end
  end
end
