require 'spec_helper'

RSpec.describe SpreePlunk::TrackEventJob, type: :job do
  let(:store) { create(:store) }
  let(:integration) { create(:plunk_integration, store: store) }

  it 'reloads shipped shipments before delegating to event tracking' do
    shipment = create(:shipped_order, store: store, email: 'buyer@example.com').shipments.first

    expect(SpreePlunk::TrackEvent).to receive(:call).with(
      plunk_integration: integration,
      event_name: SpreePlunk::EventNames::SHIPMENT_SHIPPED,
      resource: shipment,
      email: shipment.order.email
    )

    described_class.perform_now(
      integration.id,
      SpreePlunk::EventNames::SHIPMENT_SHIPPED,
      Spree::Shipment.name,
      shipment.id,
      shipment.order.email
    )
  end

  it 'reloads reimbursements before delegating to event tracking' do
    reimbursement = create(:reimbursement)

    expect(SpreePlunk::TrackEvent).to receive(:call).with(
      plunk_integration: integration,
      event_name: SpreePlunk::EventNames::REIMBURSEMENT_PAID,
      resource: reimbursement,
      email: reimbursement.order.email
    )

    described_class.perform_now(
      integration.id,
      SpreePlunk::EventNames::REIMBURSEMENT_PAID,
      Spree::Reimbursement.name,
      reimbursement.id,
      reimbursement.order.email
    )
  end

  it 'passes payload snapshots through without reloading a record' do
    payload = {
      'email' => 'newsletter@example.com',
      'verified' => true
    }

    expect(SpreePlunk::TrackEvent).to receive(:call).with(
      plunk_integration: integration,
      event_name: SpreePlunk::EventNames::NEWSLETTER_UNSUBSCRIBED,
      resource: payload,
      email: 'newsletter@example.com'
    )

    described_class.perform_now(
      integration.id,
      SpreePlunk::EventNames::NEWSLETTER_UNSUBSCRIBED,
      nil,
      nil,
      'newsletter@example.com',
      payload
    )
  end
end
