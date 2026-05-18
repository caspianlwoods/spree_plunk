module SpreePlunk
  class UnsubscribeJob < BaseJob
    def perform(plunk_integration_id, email)
      plunk_integration = ::Spree::Integrations::Plunk.find_by(id: plunk_integration_id)
      return unless plunk_integration
      return if email.blank?

      SpreePlunk::Unsubscribe.call(
        plunk_integration: plunk_integration,
        email: email
      )
    end
  end
end
