FactoryBot.define do
  factory :plunk_integration, class: Spree::Integrations::Plunk do
    active { true }
    preferred_plunk_base_url { SpreePlunk::Testing.default_base_url }
    preferred_plunk_public_api_key { SpreePlunk::Testing.default_public_api_key }
    preferred_plunk_secret_api_key { SpreePlunk::Testing.default_secret_api_key }
    store { Spree::Store.default }
  end
end
