module SpreePlunk
  class EventPresenter
    def initialize(event_name:, contact_id:, resource: nil, store: nil)
      @event_name = event_name
      @contact_id = contact_id
      @resource = resource
      @store = store
    end

    def call
      payload = {
        name: event_name,
        contactId: contact_id,
        data: event_data
      }

      payload.delete(:data) if payload[:data].empty?
      payload
    end

    private

    attr_reader :event_name, :contact_id, :resource, :store

    def event_data
      case resource
      when ::Spree::Order
        OrderPresenter.new(order: resource, store: store).call
      when ::Spree::Shipment
        ShipmentPresenter.new(shipment: resource, store: store).call
      when ::Spree::Reimbursement
        ReimbursementPresenter.new(reimbursement: resource, store: store).call
      when ::Spree::NewsletterSubscriber, Hash
        NewsletterSubscriberPresenter.new(subscriber: resource, store: store).call
      else
        {}
      end
    end
  end
end
