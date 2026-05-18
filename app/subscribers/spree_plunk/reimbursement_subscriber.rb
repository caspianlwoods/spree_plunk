module SpreePlunk
  class ReimbursementSubscriber < Spree::Subscriber
    subscribes_to 'reimbursement.reimbursed'

    on 'reimbursement.reimbursed', :handle_reimbursement_reimbursed

    private

    def handle_reimbursement_reimbursed(event)
      reimbursement = ::Spree::Reimbursement.find_by_param(event.payload['id'])
      order = reimbursement&.order
      email = order&.email
      return unless reimbursement

      integration = ::Spree::Integrations::Plunk.find_by(store_id: order&.store_id)
      return unless integration

      SpreePlunk::TrackEventJob.perform_later(
        integration.id,
        SpreePlunk::EventNames::REIMBURSEMENT_PAID,
        ::Spree::Reimbursement.name,
        reimbursement.id,
        email
      )
    end
  end
end
