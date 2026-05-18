require 'spec_helper'

RSpec.describe SpreePlunk::UpsertContactJob, type: :job do
  let(:store) { create(:store) }
  let(:integration) { create(:plunk_integration, store: store) }

  it 'reloads newsletter subscribers before delegating to contact upsert' do
    subscriber = create(:newsletter_subscriber, :verified, email: 'newsletter@example.com')

    expect(SpreePlunk::UpsertContact).to receive(:call).with(
      plunk_integration: integration,
      subscriber: subscriber
    )

    described_class.perform_now(integration.id, Spree::NewsletterSubscriber.name, subscriber.id)
  end

  it 'reloads users and optional addresses before delegating to contact upsert' do
    user = create(:user_with_addresses, email: 'user@example.com')
    address = user.bill_address || user.ship_address

    expect(SpreePlunk::UpsertContact).to receive(:call).with(
      plunk_integration: integration,
      user: user,
      address: address
    )

    described_class.perform_now(integration.id, Spree.user_class.name, user.id, address.id)
  end

  it 'skips work when the integration has been removed' do
    user = create(:user, email: 'user@example.com')

    expect(SpreePlunk::UpsertContact).not_to receive(:call)

    described_class.perform_now(-1, Spree.user_class.name, user.id)
  end
end
