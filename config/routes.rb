Spree::Core::Engine.add_routes do
  post '/plunk/webhooks/unsubscribe/:integration_id',
       to: 'plunk/unsubscribe_webhooks#create',
       as: :plunk_unsubscribe_webhook
end
