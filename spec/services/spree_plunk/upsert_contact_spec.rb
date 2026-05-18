require 'spec_helper'

RSpec.describe SpreePlunk::UpsertContact do
  subject(:result) { described_class.call(plunk_integration: plunk_integration, user: user) }

  let(:store) { create(:store, code: 'default-store') }
  let(:service_result) { Spree::ServiceModule::Result.new(true, { 'id' => 'cnt_123' }) }
  let(:plunk_integration) do
    instance_double(
      Spree::Integrations::Plunk,
      store: store,
      upsert_contact: service_result
    )
  end
  let(:user) do
    create(
      :user_with_addresses,
      email: 'user@example.com',
      accepts_email_marketing: true
    )
  end

  it 'uses the customer email marketing flag as the contact subscription state' do
    expect(plunk_integration).to receive(:upsert_contact).with(
      hash_including(
        email: 'user@example.com',
        subscribed: true
      )
    ).and_return(service_result)

    expect(result).to be_success
  end

  context 'when the user has not accepted email marketing' do
    let(:user) do
      create(
        :user_with_addresses,
        email: 'user@example.com',
        accepts_email_marketing: false
      )
    end

    it 'keeps the contact unsubscribed' do
      expect(plunk_integration).to receive(:upsert_contact).with(
        hash_including(
          email: 'user@example.com',
          subscribed: false
        )
      ).and_return(service_result)

      expect(result).to be_success
    end
  end

  context 'when no email can be resolved' do
    let(:user) do
      build(:user).tap do |record|
        record.email = nil
      end
    end

    it 'returns a noop result' do
      expect(plunk_integration).not_to receive(:upsert_contact)
      expect(result).to be_success
      expect(result.value).to include(skipped: true, reason: 'missing_email')
    end
  end
end
