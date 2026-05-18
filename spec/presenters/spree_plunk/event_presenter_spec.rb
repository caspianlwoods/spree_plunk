require 'spec_helper'

RSpec.describe SpreePlunk::EventPresenter do
  describe '#call' do
    let(:store) { create(:store, code: 'default-store') }

    context 'with an order resource' do
      let(:user) { create(:user, email: 'buyer@example.com') }
      let(:order) { create(:completed_order_with_totals, store: store, user: user, email: user.email) }

      it 'builds a Plunk event payload with order data' do
        payload = described_class.new(
          event_name: SpreePlunk::EventNames::ORDER_COMPLETED,
          contact_id: 'cnt_123',
          resource: order,
          store: store
        ).call

        expect(payload).to include(
          name: SpreePlunk::EventNames::ORDER_COMPLETED,
          contactId: 'cnt_123'
        )
        expect(payload[:data]).to include(
          order_id: order.prefixed_id,
          order_number: order.number,
          store_code: 'default-store',
          email: order.email
        )
      end
    end

    context 'with newsletter payload data' do
      let(:resource) do
        {
          'email' => 'newsletter@example.com',
          'verified' => true,
          'verified_at' => '2026-05-18T10:00:00Z',
          'customer_id' => 'cus_123'
        }
      end

      it 'builds a Plunk event payload from a hash snapshot' do
        payload = described_class.new(
          event_name: SpreePlunk::EventNames::NEWSLETTER_UNSUBSCRIBED,
          contact_id: 'cnt_456',
          resource: resource,
          store: store
        ).call

        expect(payload).to include(
          name: SpreePlunk::EventNames::NEWSLETTER_UNSUBSCRIBED,
          contactId: 'cnt_456'
        )
        expect(payload[:data]).to include(
          email: 'newsletter@example.com',
          verified: true,
          verified_at: '2026-05-18T10:00:00Z',
          customer_id: 'cus_123',
          store_code: 'default-store'
        )
      end
    end
  end
end
