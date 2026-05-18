require 'spec_helper'

RSpec.describe SpreePlunk::ReimbursementPresenter do
  it 'builds reimbursement payload details without raising when unpaid_amount is unavailable' do
    store = create(:store, code: 'default-store')
    reimbursement = create(:reimbursement)

    payload = described_class.new(reimbursement: reimbursement, store: store).call

    expect(payload).to include(
      reimbursement_number: reimbursement.number,
      reimbursement_status: reimbursement.reimbursement_status,
      order_number: reimbursement.order.number,
      return_items_count: reimbursement.return_items.size,
      store_code: 'default-store'
    )
  end
end
