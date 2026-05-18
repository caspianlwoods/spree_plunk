module SpreePlunk
  class UpsertContactJob < BaseJob
    def perform(plunk_integration_id, resource_type, resource_id, address_id = nil)
      plunk_integration = ::Spree::Integrations::Plunk.find_by(id: plunk_integration_id)
      return unless plunk_integration

      case resource_type
      when ::Spree::NewsletterSubscriber.name
        subscriber = ::Spree::NewsletterSubscriber.find_by(id: resource_id)
        return unless subscriber

        SpreePlunk::UpsertContact.call(
          plunk_integration: plunk_integration,
          subscriber: subscriber
        )
      when ::Spree.user_class.name
        user = ::Spree.user_class.find_by(id: resource_id)
        return unless user

        address = ::Spree::Address.find_by(id: address_id) if address_id.present?

        SpreePlunk::UpsertContact.call(
          plunk_integration: plunk_integration,
          user: user,
          address: address
        )
      end
    end
  end
end
