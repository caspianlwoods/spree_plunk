module SpreePlunk
  class ApplyLocalUnsubscribe < Base
    def call(email:)
      normalized_email = normalize_email(email)
      return noop_result('missing_email') if normalized_email.blank?

      subscriber = ::Spree::NewsletterSubscriber.find_by(email: normalized_email)
      user = resolved_user(email: normalized_email, subscriber: subscriber)
      return noop_result('local_email_not_found') if subscriber.blank? && user.blank?

      subscriber_id = subscriber&.id
      user_updated = false

      ::Spree::Events.disable do
        ActiveRecord::Base.transaction do
          user_updated = unsubscribe_user!(user)
          subscriber&.destroy!
        end
      end

      success(
        email: normalized_email,
        unsubscribed: true,
        subscriber_removed: subscriber.present?,
        subscriber_id: subscriber_id,
        user_updated: user_updated
      )
    rescue ActiveRecord::ActiveRecordError => e
      failure(
        {
          error_class: e.class.name,
          error_message: e.message,
          email: normalized_email,
          reason: 'persistence_error'
        },
        e.message
      )
    end

    private

    def normalize_email(value)
      value.to_s.strip.downcase.presence
    end

    def resolved_user(email:, subscriber:)
      subscriber&.user || ::Spree.user_class.find_by(email: email)
    end

    def unsubscribe_user!(user)
      return false unless user&.respond_to?(:accepts_email_marketing=)
      return false unless user.accepts_email_marketing?

      user.update!(accepts_email_marketing: false)
      true
    end
  end
end
