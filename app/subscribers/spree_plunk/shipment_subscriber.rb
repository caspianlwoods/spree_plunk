module SpreePlunk
  class ShipmentSubscriber < Spree::Subscriber
    subscribes_to 'shipment.shipped'

    on 'shipment.shipped', :handle_shipment_shipped

    private

    def handle_shipment_shipped(event)
      shipment = ::Spree::Shipment.find_by_param(event.payload['id'])
      return unless shipment

      integration = ::Spree::Integrations::Plunk.find_by(store_id: shipment.order.store_id)
      return unless integration

      SpreePlunk::TrackEventJob.perform_later(
        integration.id,
        SpreePlunk::EventNames::SHIPMENT_SHIPPED,
        ::Spree::Shipment.name,
        shipment.id,
        shipment.order.email
      )
    end
  end
end
