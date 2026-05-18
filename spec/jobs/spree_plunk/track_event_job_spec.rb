require 'spec_helper'

RSpec.describe SpreePlunk::TrackEventJob, type: :job do
  include ActiveJob::TestHelper

  let(:store) { create(:store) }
  let(:integration) { create(:plunk_integration, store: store) }

  before do
    clear_enqueued_jobs
  end

  it 'reloads shipped shipments before delegating to event tracking' do
    shipment = create(:shipped_order, store: store, email: 'buyer@example.com').shipments.first

    expect(SpreePlunk::TrackEvent).to receive(:call).with(
      plunk_integration: integration,
      event_name: SpreePlunk::EventNames::SHIPMENT_SHIPPED,
      resource: shipment,
      email: shipment.order.email
    ).and_return(Spree::ServiceModule::Result.new(true, { 'id' => 'evt_123' }))

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
    ).and_return(Spree::ServiceModule::Result.new(true, { 'id' => 'evt_123' }))

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
    ).and_return(Spree::ServiceModule::Result.new(true, { 'id' => 'evt_123' }))

    described_class.perform_now(
      integration.id,
      SpreePlunk::EventNames::NEWSLETTER_UNSUBSCRIBED,
      nil,
      nil,
      'newsletter@example.com',
      payload
    )
  end

  it 're-enqueues retryable sync failures' do
    failure_result = Spree::ServiceModule::Result.new(false, {
      status: 503,
      error_message: 'temporarily unavailable',
      error_code: 'http_503',
      retryable: true
    })

    allow(SpreePlunk::TrackEvent).to receive(:call).and_return(failure_result)

    expect {
      described_class.perform_now(
        integration.id,
        SpreePlunk::EventNames::ORDER_COMPLETED,
        nil,
        nil,
        'buyer@example.com',
        { 'email' => 'buyer@example.com' }
      )
    }.to have_enqueued_job(described_class)
  end

  it 'discards non-retryable sync failures and reports enriched context' do
    error_reporter = instance_double(ActiveSupport::ErrorReporter, report: nil)
    failure_result = Spree::ServiceModule::Result.new(false, {
      status: 401,
      error_message: 'Invalid API key',
      error_code: 'http_401',
      retryable: false
    })

    allow(Rails).to receive(:error).and_return(error_reporter)
    allow(SpreePlunk::TrackEvent).to receive(:call).and_return(failure_result)

    expect {
      described_class.perform_now(
        integration.id,
        SpreePlunk::EventNames::ORDER_COMPLETED,
        Spree::Order.name,
        123,
        'buyer@example.com'
      )
    }.not_to have_enqueued_job(described_class)

    expect(error_reporter).to have_received(:report).with(
      instance_of(SpreePlunk::DiscardableSyncError),
      hash_including(
        handled: true,
        source: 'spree.plunk',
        context: hash_including(
          operation: 'track_event',
          integration_id: integration.id,
          store_id: integration.store_id,
          event_name: SpreePlunk::EventNames::ORDER_COMPLETED,
          resource_type: Spree::Order.name,
          resource_id: 123,
          email_present: true,
          status: 401,
          error_code: 'http_401',
          discarded: true
        )
      )
    )
  end
end
