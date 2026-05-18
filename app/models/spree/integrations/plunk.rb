module Spree
  module Integrations
    class Plunk < Spree::Integration
      class ApiError < StandardError; end

      preference :plunk_base_url, :string, default: 'https://next-api.useplunk.com'
      preference :plunk_secret_api_key, :password
      preference :plunk_public_api_key, :string
      preference :default_from_email, :string
      preference :default_from_name, :string

      validates :preferred_plunk_base_url, :preferred_plunk_secret_api_key, presence: true

      def self.integration_group
        'marketing'
      end

      def can_connect?
        result = client.get('contacts?limit=1')
        @connection_error_message = extract_error_message(result.value[:body]) if result.failure?

        result.success?
      end

      def upsert_contact(payload)
        handle_result(client.post('contacts', payload))
      end

      def subscribe_contact(payload)
        handle_result(client.post('contacts', payload.merge(subscribed: true)))
      end

      def unsubscribe_contact(payload)
        handle_result(client.post('contacts', payload.merge(subscribed: false)))
      end

      def track_event(payload)
        handle_result(client.post('events/track', payload))
      end

      private

      def client
        @client ||= ::SpreePlunk::Plunk::Client.new(
          base_url: preferred_plunk_base_url,
          secret_api_key: preferred_plunk_secret_api_key
        )
      end

      def handle_result(result)
        if result.success?
          Spree::ServiceModule::Result.new(true, result.value[:body])
        else
          error_message = extract_error_message(result.value[:body])

          Rails.error.report(
            ApiError.new(error_message),
            context: {
              integration_id: id,
              status: result.value[:status],
              error_message: error_message
            },
            source: 'spree.plunk'
          )

          Spree::ServiceModule::Result.new(false, result.value[:body])
        end
      end

      def extract_error_message(body)
        case body
        when Hash
          body['error'] || body['message'] || body.dig('errors', 0, 'message') || body.dig('errors', 0, 'detail') || body.inspect
        else
          body.to_s
        end
      end
    end
  end
end
