module SpreePlunk
  class Configuration < Spree::Preferences::Configuration
    preference :plunk_api_url, :string, default: 'https://next-api.useplunk.com'
    preference :plunk_api_open_timeout, :integer, default: 10
    preference :plunk_api_read_timeout, :integer, default: 10
  end
end
