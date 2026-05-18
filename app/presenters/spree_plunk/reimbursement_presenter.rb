module SpreePlunk
  class ReimbursementPresenter
    def initialize(reimbursement:, store: nil)
      @reimbursement = reimbursement
      @store = store
    end

    def call
      {
        reimbursement_id: reimbursement.prefixed_id,
        reimbursement_number: reimbursement.number,
        reimbursement_status: reimbursement.reimbursement_status,
        store_code: store_code,
        order_id: order&.prefixed_id,
        order_number: order&.number,
        currency: reimbursement.currency,
        total: reimbursement.total.to_f,
        paid_amount: reimbursement.paid_amount.to_f,
        unpaid_amount: reimbursement.unpaid_amount.to_f,
        return_items_count: reimbursement.return_items.size,
        performed_by_id: reimbursement.performed_by&.id
      }.reject { |_key, value| value.nil? || value == '' }
    end

    private

    attr_reader :reimbursement, :store

    def order
      reimbursement.order
    end

    def store_code
      store&.code || reimbursement.store&.code
    end
  end
end
