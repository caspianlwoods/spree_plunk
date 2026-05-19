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

  it 'runs synchronously so shipment tracking only needs the Plunk job queue' do
    expect(described_class.subscription_options).to eq(async: false)
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

  it 'skips tracking when the shipment no longer has an order' do
    orderless_shipment = instance_double(Spree::Shipment, id: 42, order: nil)
    event = Spree::Event.new(
      name: 'shipment.shipped',
      payload: { 'id' => 'ship_test' }
    )

    allow(Spree::Shipment).to receive(:find_by_param).and_return(orderless_shipment)

    expect {
      subscriber.send(:handle_shipment_shipped, event)
    }.not_to have_enqueued_job(SpreePlunk::TrackEventJob)
  end
end
