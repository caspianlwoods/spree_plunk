require 'spec_helper'

RSpec.describe SpreePlunk::ContactSubscriber do
  include ActiveJob::TestHelper

  let(:store) { create(:store) }
  let(:integration) { create(:plunk_integration, store: store) }
  let(:subscriber) { described_class.new }
  let(:user) { create(:user_with_addresses, email: 'buyer@example.com') }

  before do
    integration
    allow(Spree::Store).to receive(:default).and_return(store)
    clear_enqueued_jobs
  end

  it 'runs synchronously so contact sync only needs the Plunk job queue' do
    expect(described_class.subscription_options).to eq(async: false)
  end

  it 'enqueues contact upsert for user lifecycle events' do
    event = Spree::Event.new(
      name: 'user.updated',
      payload: { 'id' => user.to_param }
    )

    expect {
      subscriber.send(:handle_user_event, event)
    }.to have_enqueued_job(SpreePlunk::UpsertContactJob).with(
      integration.id,
      Spree.user_class.name,
      user.id
    )
  end

  it 'enqueues contact upsert for address lifecycle events' do
    address = user.bill_address || user.ship_address
    event = Spree::Event.new(
      name: 'address.updated',
      payload: { 'id' => address.to_param }
    )

    expect {
      subscriber.send(:handle_address_event, event)
    }.to have_enqueued_job(SpreePlunk::UpsertContactJob).with(
      integration.id,
      Spree.user_class.name,
      user.id,
      address.id
    )
  end

  it 'skips address events that are not attached to a user' do
    orphan_address = create(:address, user: nil)
    event = Spree::Event.new(
      name: 'address.updated',
      payload: { 'id' => orphan_address.to_param }
    )

    expect {
      subscriber.send(:handle_address_event, event)
    }.not_to have_enqueued_job(SpreePlunk::UpsertContactJob)
  end
end
