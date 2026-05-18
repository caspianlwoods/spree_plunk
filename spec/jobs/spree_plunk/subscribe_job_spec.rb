require 'spec_helper'

RSpec.describe SpreePlunk::SubscribeJob, type: :job do
  let(:store) { create(:store) }
  let(:integration) { create(:plunk_integration, store: store) }

  it 'reloads subscribers before delegating to the subscribe service' do
    subscriber = create(:newsletter_subscriber, :verified, email: 'newsletter@example.com')

    expect(SpreePlunk::Subscribe).to receive(:call).with(
      plunk_integration: integration,
      subscriber: subscriber
    )

    described_class.perform_now(integration.id, subscriber.id)
  end

  it 'skips work when the subscriber no longer exists' do
    expect(SpreePlunk::Subscribe).not_to receive(:call)

    described_class.perform_now(integration.id, -1)
  end
end
