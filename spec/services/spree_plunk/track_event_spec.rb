require 'spec_helper'

RSpec.describe SpreePlunk::TrackEvent do
  subject(:result) do
    described_class.call(
      plunk_integration: plunk_integration,
      event_name: event_name,
      resource: resource,
      email: email
    )
  end

  let(:store) { create(:store, code: 'default-store') }
  let(:plunk_integration) do
    instance_double(
      Spree::Integrations::Plunk,
      store: store,
      track_event: track_result
    )
  end
  let(:track_result) { Spree::ServiceModule::Result.new(true, { 'id' => 'evt_123' }) }
  let(:contact_result) { Spree::ServiceModule::Result.new(true, { 'id' => 'cnt_123' }) }
  let(:event_name) { SpreePlunk::EventNames::ORDER_COMPLETED }
  let(:email) { nil }
  let(:user) { create(:user, email: 'buyer@example.com') }
  let(:resource) { create(:completed_order_with_totals, store: store, user: user, email: user.email) }

  before do
    allow(SpreePlunk::UpsertContact).to receive(:call).and_return(contact_result)
  end

  it 'ensures the contact exists without implicitly subscribing it' do
    expect(SpreePlunk::UpsertContact).to receive(:call).with(
      hash_including(
        plunk_integration: plunk_integration,
        user: resource.user,
        address: resource.bill_address,
        email: resource.email,
        subscribed: false
      )
    ).and_return(contact_result)

    expect(plunk_integration).to receive(:track_event).with(
      hash_including(
        name: SpreePlunk::EventNames::ORDER_COMPLETED,
        contactId: 'cnt_123'
      )
    ).and_return(track_result)

    expect(result).to be_success
  end

  context 'when tracking a newsletter subscription event' do
    let(:event_name) { SpreePlunk::EventNames::NEWSLETTER_SUBSCRIBED }
    let(:resource) { create(:newsletter_subscriber, :verified, email: 'newsletter@example.com') }

    it 'upserts the contact as subscribed before tracking' do
      expect(SpreePlunk::UpsertContact).to receive(:call).with(
        hash_including(
          subscriber: resource,
          email: 'newsletter@example.com',
          subscribed: true
        )
      ).and_return(contact_result)

      expect(plunk_integration).to receive(:track_event).and_return(track_result)

      expect(result).to be_success
    end
  end

  context 'when no email can be resolved' do
    let(:resource) { nil }

    it 'returns a noop result and does not track the event' do
      expect(SpreePlunk::UpsertContact).not_to receive(:call)
      expect(plunk_integration).not_to receive(:track_event)

      expect(result).to be_success
      expect(result.value).to include(skipped: true, reason: 'missing_email')
    end
  end
end
