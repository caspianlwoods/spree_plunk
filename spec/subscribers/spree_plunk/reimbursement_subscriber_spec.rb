require 'spec_helper'

RSpec.describe SpreePlunk::ReimbursementSubscriber do
  include ActiveJob::TestHelper

  let(:store) { create(:store) }
  let(:integration) { create(:plunk_integration, store: store) }
  let(:subscriber) { described_class.new }
  let(:order) { instance_double(Spree::Order, store_id: store.id, email: 'buyer@example.com') }
  let(:reimbursement) { instance_double(Spree::Reimbursement, id: 42, order: order) }

  before do
    integration
    allow(Spree::Reimbursement).to receive(:find_by_param).and_return(reimbursement)
    clear_enqueued_jobs
  end

  it 'runs synchronously so reimbursement tracking only needs the Plunk job queue' do
    expect(described_class.subscription_options).to eq(async: false)
  end

  it 'enqueues tracking for reimbursed reimbursements' do
    event = Spree::Event.new(
      name: 'reimbursement.reimbursed',
      payload: { 'id' => 'reimb_test' }
    )

    expect {
      subscriber.send(:handle_reimbursement_reimbursed, event)
    }.to have_enqueued_job(SpreePlunk::TrackEventJob).with(
      integration.id,
      SpreePlunk::EventNames::REIMBURSEMENT_PAID,
      Spree::Reimbursement.name,
      reimbursement.id,
      reimbursement.order.email
    )
  end

  it 'skips tracking when the reimbursement no longer has an order' do
    orderless_reimbursement = instance_double(Spree::Reimbursement, id: 42, order: nil)
    event = Spree::Event.new(
      name: 'reimbursement.reimbursed',
      payload: { 'id' => 'reimb_test' }
    )

    allow(Spree::Reimbursement).to receive(:find_by_param).and_return(orderless_reimbursement)

    expect {
      subscriber.send(:handle_reimbursement_reimbursed, event)
    }.not_to have_enqueued_job(SpreePlunk::TrackEventJob)
  end
end
