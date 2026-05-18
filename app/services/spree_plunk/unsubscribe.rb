module SpreePlunk
  class Unsubscribe < Base
    prepend ::Spree::ServiceModule::Base

    def call(plunk_integration:, email:)
      return noop_result('missing_email') if email.blank?

      user = ::Spree.user_class.find_by(email: email)
      payload = ContactPresenter.new(
        user: user,
        email: email,
        store: plunk_integration.store
      ).call(subscribed: false)

      plunk_integration.unsubscribe_contact(payload)
    end
  end
end
