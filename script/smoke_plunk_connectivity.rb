#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
require 'json'
require 'socket'

ENV['RAILS_ENV'] ||= 'test'
ENV.delete('HTTP_PROXY')

require_relative '../spec/dummy/config/environment'

module SmokePlunkConnectivity
  module_function

  Scenario = Struct.new(:name, :integration, :expected_success, :expected_message_fragment, keyword_init: true)

  def run!
    ensure_dummy_app!

    server, thread, port = start_fake_plunk_server

    scenarios = [
      Scenario.new(
        name: 'success',
        integration: build_integration(
          base_url: "http://127.0.0.1:#{port}/success",
          secret_api_key: 'sk_test_smoke'
        ),
        expected_success: true,
        expected_message_fragment: nil
      ),
      Scenario.new(
        name: 'unauthorized',
        integration: build_integration(
          base_url: "http://127.0.0.1:#{port}/unauthorized",
          secret_api_key: 'sk_bad_smoke'
        ),
        expected_success: false,
        expected_message_fragment: 'secret API key'
      ),
      Scenario.new(
        name: 'missing_endpoint',
        integration: build_integration(
          base_url: "http://127.0.0.1:#{port}/missing",
          secret_api_key: 'sk_test_smoke'
        ),
        expected_success: false,
        expected_message_fragment: 'expected Plunk API endpoint was not found'
      ),
      Scenario.new(
        name: 'invalid_base_url',
        integration: build_integration(
          base_url: "http://127.0.0.1:#{port}/events/track",
          secret_api_key: 'sk_test_smoke'
        ),
        expected_success: false,
        expected_message_fragment: 'API base URL'
      )
    ]

    failures = scenarios.filter_map { |scenario| verify_scenario(scenario) }

    puts
    if failures.empty?
      puts 'Smoke check passed: Plunk connectivity scenarios behaved as expected.'
    else
      warn 'Smoke check failed:'
      failures.each { |failure| warn "  - #{failure}" }
      exit 1
    end
  ensure
    server&.close
    thread&.join
  end

  def ensure_dummy_app!
    dummy_app_path = File.expand_path('../spec/dummy/config/environment.rb', __dir__)
    return if File.exist?(dummy_app_path)

    abort 'Missing spec/dummy. Run `SPREE_PATH=ref/spree/spree bundle exec rake test_app` first.'
  end

  def start_fake_plunk_server
    port = TCPServer.open('127.0.0.1', 0) { |server| server.addr[1] }
    server = TCPServer.new('127.0.0.1', port)

    thread = Thread.new do
      loop do
        client = server.accept
        request_line = client.gets
        next if request_line.nil?

        method, path_with_query, = request_line.split
        headers = read_headers(client)
        path = path_with_query.to_s.split('?').first
        status, body = response_for(method: method, path: path, headers: headers)

        client.write <<~HTTP
          HTTP/1.1 #{status} #{reason_phrase(status)}
          Content-Type: application/json
          Content-Length: #{body.bytesize}
          Connection: close

          #{body}
        HTTP
      rescue IOError, Errno::EBADF
        break
      ensure
        client&.close
      end
    end

    sleep 0.2

    [server, thread, port]
  end

  def read_headers(client)
    headers = {}

    while (line = client.gets)
      break if line == "\r\n"

      key, value = line.split(':', 2)
      headers[key] = value.to_s.strip
    end

    headers
  end

  def response_for(method:, path:, headers:)
    return [405, JSON.generate('error' => 'Method not allowed')] unless method == 'GET'

    case path
    when '/success/contacts'
      if headers['Authorization'] == 'Bearer sk_test_smoke'
        [200, JSON.generate('contacts' => [])]
      else
        [401, JSON.generate('error' => 'Invalid API key')]
      end
    when '/unauthorized/contacts'
      [401, JSON.generate('error' => 'Invalid API key')]
    when '/missing/contacts'
      [404, JSON.generate('error' => 'Route not found')]
    else
      [404, JSON.generate('error' => 'Route not found')]
    end
  end

  def reason_phrase(status)
    case status
    when 200 then 'OK'
    when 401 then 'Unauthorized'
    when 404 then 'Not Found'
    else 'Error'
    end
  end

  def build_integration(base_url:, secret_api_key:)
    Spree::Integrations::Plunk.new(
      store: default_store,
      preferred_plunk_base_url: base_url,
      preferred_plunk_secret_api_key: secret_api_key
    )
  end

  def default_store
    @default_store ||= begin
      Spree::Store.find_by(default: true) || Spree::Store.create!(
        name: 'Smoke Store',
        url: 'smoke.test',
        mail_from_address: 'smoke@example.com',
        code: 'smoke',
        default: true
      )
    end
  end

  def verify_scenario(scenario)
    success = scenario.integration.can_connect?
    message = scenario.integration.connection_error_message

    puts "[#{scenario.name}] success=#{success.inspect} message=#{message.inspect}"

    return "#{scenario.name}: expected success=#{scenario.expected_success.inspect}, got #{success.inspect}" unless success == scenario.expected_success
    return nil if scenario.expected_message_fragment.nil?
    return nil if message.to_s.include?(scenario.expected_message_fragment)

    "#{scenario.name}: expected message to include #{scenario.expected_message_fragment.inspect}, got #{message.inspect}"
  end
end

SmokePlunkConnectivity.run!
