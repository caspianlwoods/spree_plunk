module SpreePlunk
  class NewsletterSubscriber < Spree::Subscriber
    subscribes_to 'newsletter_subscriber.created', 'newsletter_subscriber.updated', 'newsletter_subscriber.deleted'

    on 'newsletter_subscriber.created', :handle_subscriber_sync
    on 'newsletter_subscriber.updated', :handle_subscriber_sync
    on 'newsletter_subscriber.deleted', :handle_subscriber_deletion

    private

    def handle_subscriber_sync(event)
      subscriber = find_subscriber(event.payload['id'])
      return unless subscriber

      integration = plunk_integration(event)
      return unless integration

      if subscriber.accepts_email_marketing
        SpreePlunk::SubscribeJob.perform_later(integration.id, subscriber.id)
      else
        SpreePlunk::UpsertContactJob.perform_later(integration.id, ::Spree::NewsletterSubscriber.name, subscriber.id)
      end
    end

    def handle_subscriber_deletion(event)
      email = event.payload['email']
      return if email.blank?

      integration = plunk_integration(event)
      return unless integration

      SpreePlunk::UnsubscribeJob.perform_later(integration.id, email)
    end

    def find_subscriber(value)
      return if value.blank?

      if ::Spree::NewsletterSubscriber.respond_to?(:find_by_param)
        ::Spree::NewsletterSubscriber.find_by_param(value)
      elsif ::Spree::NewsletterSubscriber.respond_to?(:find_by_prefix_id)
        ::Spree::NewsletterSubscriber.find_by_prefix_id(value)
      else
        ::Spree::NewsletterSubscriber.find_by(id: value)
      end
    end

    def plunk_integration(event)
      store_id = event.store_id.presence || ::Spree::Store.default&.id
      return if store_id.blank?

      ::Spree::Integrations::Plunk.find_by(store_id: store_id)
    end
  end
end
