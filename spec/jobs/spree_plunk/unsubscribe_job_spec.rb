require 'spec_helper'

RSpec.describe SpreePlunk::UnsubscribeJob, type: :job do
  let(:store) { create(:store) }
  let(:integration) { create(:plunk_integration, store: store) }

  it 'delegates unsubscribe work with the resolved email address' do
    expect(SpreePlunk::Unsubscribe).to receive(:call).with(
      plunk_integration: integration,
      email: 'newsletter@example.com'
    )

    described_class.perform_now(integration.id, 'newsletter@example.com')
  end

  it 'skips work when the email is blank' do
    expect(SpreePlunk::Unsubscribe).not_to receive(:call)

    described_class.perform_now(integration.id, '')
  end
end
