Rails.application.config.after_initialize do
  Rails.application.config.spree.integrations << Spree::Integrations::Plunk
  Spree.subscribers << SpreePlunk::ContactSubscriber
  Spree.subscribers << SpreePlunk::NewsletterSubscriber
end
