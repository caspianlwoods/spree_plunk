module SpreePlunk
  class SubscribeJob < BaseJob
    def perform(plunk_integration_id, subscriber_id)
      plunk_integration = ::Spree::Integrations::Plunk.find_by(id: plunk_integration_id)
      return unless plunk_integration

      subscriber = ::Spree::NewsletterSubscriber.find_by(id: subscriber_id)
      return unless subscriber

      SpreePlunk::Subscribe.call(
        plunk_integration: plunk_integration,
        subscriber: subscriber
      )
    end
  end
end
