require 'spec_helper'

RSpec.describe Spree::Integrations::Plunk, type: :model do
  let(:store) { Spree::Store.default }

  describe '.icon_path' do
    it 'exposes an integration card icon for the admin list' do
      expect(described_class.icon_path).to start_with('data:image/png;base64,')
    end
  end

  describe 'validations' do
    it 'normalizes operator-entered preference values before validation' do
      integration = build(
        :plunk_integration,
        store: store,
        preferred_plunk_base_url: ' https://plunk.example.com/api/ ',
        preferred_plunk_secret_api_key: " sk_test_123 \n",
        preferred_plunk_public_api_key: ' pk_test_123 ',
        preferred_default_from_email: ' Marketing@Example.com ',
        preferred_default_from_name: ' Example Store '
      )

      integration.valid?

      aggregate_failures do
        expect(integration.preferred_plunk_base_url).to eq('https://plunk.example.com/api')
        expect(integration.preferred_plunk_secret_api_key).to eq('sk_test_123')
        expect(integration.preferred_plunk_public_api_key).to eq('pk_test_123')
        expect(integration.preferred_default_from_email).to eq('marketing@example.com')
        expect(integration.preferred_default_from_name).to eq('Example Store')
      end
    end

    it 'rejects a Plunk base URL that points at a specific endpoint path' do
      integration = build(
        :plunk_integration,
        store: store,
        preferred_plunk_base_url: 'https://plunk.example.com/contacts'
      )

      expect(integration).not_to be_valid
      expect(integration.errors[:preferred_plunk_base_url]).to include('must be the API base URL, not a specific endpoint path')
    end

    it 'rejects a sender name without a sender email' do
      integration = build(
        :plunk_integration,
        store: store,
        preferred_default_from_email: '',
        preferred_default_from_name: 'Example Store'
      )

      expect(integration).not_to be_valid
      expect(integration.errors[:preferred_default_from_email]).to include('is required when Default Sender Name is set')
    end

    it 'rejects secret API keys that contain whitespace' do
      integration = build(
        :plunk_integration,
        store: store,
        preferred_plunk_secret_api_key: 'sk test'
      )

      expect(integration).not_to be_valid
      expect(integration.errors[:preferred_plunk_secret_api_key]).to include('must not contain spaces or line breaks')
    end
  end

  describe '#can_connect?' do
    context 'when the local configuration is invalid' do
      it 'fails before making a network request and explains what to fix' do
        integration = build(
          :plunk_integration,
          store: store,
          preferred_plunk_base_url: 'https://plunk.example.com/events/track'
        )

        expect(integration.can_connect?).to be(false)
        expect(a_request(:get, 'https://plunk.example.com/events/track/contacts?limit=1')).not_to have_been_made
        expect(integration.connection_error_message).to eq(
          'Review the highlighted configuration fields: Plunk Base URL must be the API base URL, not a specific endpoint path'
        )
      end
    end

    context 'when Plunk accepts the credentials' do
      it 'returns true and clears any prior connection error message' do
        integration = build(:plunk_integration, store: store)
        integration.connection_error_message = 'old error'

        stub_request(:get, 'https://next-api.useplunk.com/contacts?limit=1')
          .with(headers: { 'Authorization' => "Bearer #{integration.preferred_plunk_secret_api_key}" })
          .to_return(status: 200, body: '{"contacts":[]}', headers: { 'Content-Type' => 'application/json' })

        expect(integration.can_connect?).to be(true)
        expect(integration.connection_error_message).to be_nil
      end
    end

    context 'when the secret API key is rejected' do
      it 'returns a clear operator-facing authentication error' do
        integration = build(:plunk_integration, store: store)

        stub_request(:get, 'https://next-api.useplunk.com/contacts?limit=1')
          .to_return(status: 401, body: '{"error":"Invalid API key"}', headers: { 'Content-Type' => 'application/json' })

        expect(integration.can_connect?).to be(false)
        expect(integration.connection_error_message).to eq(
          'Plunk rejected the secret API key. Confirm that you pasted a valid secret server key for this workspace and try again.'
        )
      end
    end

    context 'when the API is unreachable' do
      it 'returns network troubleshooting guidance' do
        integration = build(
          :plunk_integration,
          store: store,
          preferred_plunk_base_url: 'https://plunk.internal.example'
        )

        stub_request(:get, 'https://plunk.internal.example/contacts?limit=1').to_timeout

        expect(integration.can_connect?).to be(false)
        expect(integration.connection_error_message).to eq(
          'Spree timed out while contacting Plunk at https://plunk.internal.example. Check DNS, port, TLS, firewall, and that the self-hosted API is reachable from the app server.'
        )
      end
    end
  end
end
