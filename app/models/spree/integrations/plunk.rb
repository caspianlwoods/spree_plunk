require 'base64'

module Spree
  module Integrations
    class Plunk < Spree::Integration
      class ApiError < StandardError; end

      CONNECTION_CHECK_PATH = 'contacts?limit=1'.freeze
      KNOWN_ENDPOINT_PATHS = %w[/contacts /contacts/lookup /events/track /v1/track /v1/send].freeze
      MAX_URL_LENGTH = 255
      MAX_API_KEY_LENGTH = 255
      MAX_SENDER_EMAIL_LENGTH = 255
      MAX_SENDER_NAME_LENGTH = 255
      PLUNK_LOGO_PATH = SpreePlunk::Engine.root.join('app/assets/images/integration_icons/plunk-logo.png')
      preference :plunk_base_url, :string, default: 'https://next-api.useplunk.com'
      preference :plunk_secret_api_key, :password
      preference :plunk_public_api_key, :string
      preference :default_from_email, :string
      preference :default_from_name, :string

      before_validation :normalize_preferences

      validates :preferred_plunk_base_url, :preferred_plunk_secret_api_key, presence: true
      validates :preferred_plunk_base_url, length: { maximum: MAX_URL_LENGTH }, allow_blank: true
      validates :preferred_plunk_secret_api_key, length: { maximum: MAX_API_KEY_LENGTH }, allow_blank: true
      validates :preferred_plunk_public_api_key, length: { maximum: MAX_API_KEY_LENGTH }, allow_blank: true
      validates :preferred_default_from_email, length: { maximum: MAX_SENDER_EMAIL_LENGTH }, allow_blank: true,
                                                      format: { with: URI::MailTo::EMAIL_REGEXP, message: :invalid_email_address }
      validates :preferred_default_from_name, length: { maximum: MAX_SENDER_NAME_LENGTH }, allow_blank: true

      validate :validate_plunk_base_url
      validate :validate_api_keys
      validate :validate_sender_defaults

      def self.integration_group
        'marketing'
      end

      def self.icon_path
        return unless PLUNK_LOGO_PATH.exist?

        @icon_path ||= "data:image/png;base64,#{Base64.strict_encode64(PLUNK_LOGO_PATH.binread)}"
      end

      def can_connect?
        self.connection_error_message = nil

        unless valid?
          self.connection_error_message = invalid_configuration_message
          return false
        end

        result = client.get(CONNECTION_CHECK_PATH)
        self.connection_error_message = connection_error_message_for(result) if result.failure?

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
        ::SpreePlunk::Plunk::Client.new(
          base_url: preferred_plunk_base_url,
          secret_api_key: preferred_plunk_secret_api_key
        )
      end

      def normalize_preferences
        self.preferred_plunk_base_url = normalize_string(preferred_plunk_base_url)&.sub(%r{/*\z}, '')
        self.preferred_plunk_secret_api_key = normalize_string(preferred_plunk_secret_api_key)
        self.preferred_plunk_public_api_key = normalize_string(preferred_plunk_public_api_key)
        self.preferred_default_from_email = normalize_string(preferred_default_from_email)&.downcase
        self.preferred_default_from_name = normalize_string(preferred_default_from_name)
      end

      def normalize_string(value)
        return value unless value.is_a?(String)

        value.strip.presence
      end

      def validate_plunk_base_url
        return if preferred_plunk_base_url.blank?

        uri = URI.parse(preferred_plunk_base_url)

        unless uri.is_a?(URI::HTTP) && uri.host.present?
          errors.add(:preferred_plunk_base_url, :invalid_http_url)
          return
        end

        errors.add(:preferred_plunk_base_url, :query_or_fragment_not_allowed) if uri.query.present? || uri.fragment.present?
        errors.add(:preferred_plunk_base_url, :endpoint_path_not_allowed) if endpoint_path?(uri.path)
      rescue URI::InvalidURIError
        errors.add(:preferred_plunk_base_url, :invalid_http_url)
      end

      def validate_api_keys
        validate_key_whitespace(:preferred_plunk_secret_api_key)
        validate_key_whitespace(:preferred_plunk_public_api_key)
      end

      def validate_key_whitespace(attribute)
        return if public_send(attribute).blank?

        errors.add(attribute, :whitespace_not_allowed) if public_send(attribute).match?(/\s/)
      end

      def validate_sender_defaults
        return unless preferred_default_from_name.present? && preferred_default_from_email.blank?

        errors.add(:preferred_default_from_email, :required_when_sender_name_present)
      end

      def endpoint_path?(path)
        normalized_path = path.to_s.sub(%r{/*\z}, '')
        KNOWN_ENDPOINT_PATHS.include?(normalized_path)
      end

      def invalid_configuration_message
        "Review the highlighted configuration fields: #{errors.full_messages.uniq.to_sentence}"
      end

      def connection_error_message_for(result)
        status = result.value[:status]
        message = extract_error_message(result.value[:body])

        return invalid_secret_api_key_message if [401, 403].include?(status)
        return missing_api_endpoint_message if status == 404
        return timeout_connection_message if timeout_error?(message)
        return unreachable_connection_message if transport_error?(message)
        return "Plunk returned HTTP #{status}: #{message}" if status.present? && message.present?
        return "Plunk returned HTTP #{status} during the connection check." if status.present?

        message.presence || 'The Plunk connection check failed for an unknown reason.'
      end

      def invalid_secret_api_key_message
        'Plunk rejected the secret API key. Confirm that you pasted a valid secret server key for this workspace and try again.'
      end

      def missing_api_endpoint_message
        "Spree reached #{preferred_plunk_base_url}, but the expected Plunk API endpoint was not found. Use the API base URL only, not a specific endpoint path."
      end

      def timeout_connection_message
        "Spree timed out while contacting Plunk at #{preferred_plunk_base_url}. Check DNS, port, TLS, firewall, and that the self-hosted API is reachable from the app server."
      end

      def unreachable_connection_message
        "Spree could not reach Plunk at #{preferred_plunk_base_url}. Check DNS, port, TLS, firewall, and that the self-hosted API is reachable from the app server."
      end

      def timeout_error?(message)
        message.to_s.match?(/execution expired|timed out|timeout/i)
      end

      def transport_error?(message)
        message.to_s.match?(/getaddrinfo|failed to open tcp connection|connection refused|no route to host|econnrefused|ssl_connect|certificate/i)
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
          errors = body['errors']

          body['error'] ||
            body['message'] ||
            (errors.first if errors.is_a?(Array) && errors.first.is_a?(String)) ||
            body.dig('errors', 0, 'message') ||
            body.dig('errors', 0, 'detail') ||
            body.inspect
        else
          body.to_s
        end
      end
    end
  end
end
