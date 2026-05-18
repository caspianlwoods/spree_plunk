require 'spec_helper'

RSpec.describe SpreePlunk::ShipmentPresenter do
  it 'builds shipment payload details for shipped orders' do
    store = create(:store, code: 'default-store')
    shipment = create(:shipped_order, store: store, email: 'buyer@example.com').shipments.first
    shipment.update_column(:shipped_at, Time.utc(2026, 5, 18, 10, 0, 0))

    payload = described_class.new(shipment: shipment, store: store).call

    expect(payload).to include(
      shipment_number: shipment.number,
      tracking: shipment.tracking,
      order_number: shipment.order.number,
      store_code: 'default-store',
      shipped_at: shipment.shipped_at.iso8601
    )
  end
end
