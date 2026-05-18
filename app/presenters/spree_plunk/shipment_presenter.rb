module SpreePlunk
  class ShipmentPresenter
    def initialize(shipment:, store: nil)
      @shipment = shipment
      @store = store
    end

    def call
      {
        shipment_id: shipment.prefixed_id,
        shipment_number: shipment.number,
        shipment_state: shipment.state,
        tracking: shipment.tracking,
        shipping_method: shipment.shipping_method&.name,
        stock_location_name: shipment.stock_location&.name,
        store_code: store_code,
        order_id: order&.prefixed_id,
        order_number: order&.number,
        currency: shipment.currency,
        cost: shipment.cost.to_f,
        total: shipment.total.to_f,
        discount_total: shipment.promo_total.to_f,
        shipped_at: iso8601(shipment.shipped_at)
      }.reject { |_key, value| value.nil? || value == '' }
    end

    private

    attr_reader :shipment, :store

    def order
      shipment.order
    end

    def store_code
      store&.code || shipment.store&.code
    end

    def iso8601(value)
      value&.iso8601
    end
  end
end
