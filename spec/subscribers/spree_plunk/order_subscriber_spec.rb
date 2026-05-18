require 'spec_helper'

RSpec.describe SpreePlunk::OrderSubscriber do
  include ActiveJob::TestHelper

  let(:store) { create(:store) }
  let(:integration) { create(:plunk_integration, store: store) }
  let(:subscriber) { described_class.new }
  let(:user) { create(:user, email: 'buyer@example.com') }
  let(:order) { create(:completed_order_with_totals, store: store, user: user, email: user.email) }

  before do
    integration
    clear_enqueued_jobs
  end

  it 'enqueues tracking for order completion' do
    event = Spree::Event.new(
      name: 'order.completed',
      payload: { 'id' => order.to_param }
    )

    expect {
      subscriber.send(:handle_order_completed, event)
    }.to have_enqueued_job(SpreePlunk::TrackEventJob).with(
      integration.id,
      SpreePlunk::EventNames::ORDER_COMPLETED,
      Spree::Order.name,
      order.id,
      order.email
    )
  end
end
