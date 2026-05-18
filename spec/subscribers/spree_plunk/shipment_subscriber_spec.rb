require 'spec_helper'

RSpec.describe SpreePlunk::ShipmentSubscriber do
  include ActiveJob::TestHelper

  let(:store) { create(:store) }
  let(:integration) { create(:plunk_integration, store: store) }
  let(:subscriber) { described_class.new }
  let(:shipment) { create(:shipped_order, store: store).shipments.first }

  before do
    integration
    clear_enqueued_jobs
  end

  it 'enqueues tracking for shipped shipments' do
    event = Spree::Event.new(
      name: 'shipment.shipped',
      payload: { 'id' => shipment.to_param }
    )

    expect {
      subscriber.send(:handle_shipment_shipped, event)
    }.to have_enqueued_job(SpreePlunk::TrackEventJob).with(
      integration.id,
      SpreePlunk::EventNames::SHIPMENT_SHIPPED,
      Spree::Shipment.name,
      shipment.id,
      shipment.order.email
    )
  end
end
