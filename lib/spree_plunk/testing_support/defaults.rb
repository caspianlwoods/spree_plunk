module SpreePlunk
  module Testing
    module_function

    def default_base_url
      ENV.fetch('PLUNK_BASE_URL', 'https://next-api.useplunk.com')
    end

    def default_public_api_key
      ENV.fetch('PLUNK_PUBLIC_API_KEY', 'pk_test_1234')
    end

    def default_secret_api_key
      ENV.fetch('PLUNK_SECRET_API_KEY', 'sk_test_1234')
    end
  end
end
