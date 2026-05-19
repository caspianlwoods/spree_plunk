module SpreePlunk
  class ContactSubscriber < Spree::Subscriber
    subscribes_to 'user.created', 'user.updated', 'address.created', 'address.updated', async: false

    on 'user.created', :handle_user_event
    on 'user.updated', :handle_user_event
    on 'address.created', :handle_address_event
    on 'address.updated', :handle_address_event

    private

    def handle_user_event(event)
      user = find_record(::Spree.user_class, event.payload['id'])
      return unless user

      integration = plunk_integration(event)
      return unless integration

      SpreePlunk::UpsertContactJob.perform_later(integration.id, ::Spree.user_class.name, user.id)
    end

    def handle_address_event(event)
      address = find_record(::Spree::Address, event.payload['id'])
      user = address&.user
      return unless user

      integration = plunk_integration(event)
      return unless integration

      SpreePlunk::UpsertContactJob.perform_later(integration.id, ::Spree.user_class.name, user.id, address.id)
    end

    def find_record(klass, value)
      return if value.blank?

      if klass.respond_to?(:find_by_param)
        klass.find_by_param(value)
      elsif klass.respond_to?(:find_by_prefix_id)
        klass.find_by_prefix_id(value)
      else
        klass.find_by(id: value)
      end
    end

    def plunk_integration(event)
      store_id = event.store_id.presence || ::Spree::Store.default&.id
      return if store_id.blank?

      ::Spree::Integrations::Plunk.find_by(store_id: store_id)
    end
  end
end
