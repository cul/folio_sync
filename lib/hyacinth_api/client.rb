# frozen_string_literal: true

class HyacinthApi::Client
  include HyacinthApi::Finders
  include HyacinthApi::DigitalObjects

  attr_reader :config

  def initialize(config)
    @config = config
    @auth_token = Base64.strict_encode64("#{@config.email}:#{@config.password}")
  end

  def self.instance
    @instance ||= new
  end

  # Core HTTP methods
  def get(path, params = {})
    response = connection.get(path, params)
    handle_response(response)
  end

  def post(path, data = {})
    response = connection.post(path, data.to_json)
    handle_response(response)
  end

  def put(path, data = {})
    response = connection.put(path, data.to_json)
    handle_response(response)
  end

  def delete(path)
    response = connection.delete(path)
    handle_response(response)
  end

  def connection
    @connection ||= Faraday.new(
      url: @config.url,
      headers: headers,
      request: { timeout: @config.timeout }
    ) do |faraday|
      faraday.adapter Faraday.default_adapter
      faraday.use Faraday::Response::RaiseError
    end
  end

  def headers
    {
      'Accept' => 'application/json, text/plain',
      'Content-Type' => 'application/json',
      'Authorization' => "Basic #{@auth_token}"
    }
  end

  def handle_response(response)
    return {} if response.body.blank?

    JSON.parse(response.body)
  rescue JSON::ParserError => e
    Rails.logger.error("Invalid JSON response: #{response.body}")
    raise "Invalid JSON response: #{e.message}"
  end
end