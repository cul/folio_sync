# frozen_string_literal: true

class Hyacinth::ApiClient
  include Hyacinth::Finders

  attr_reader :config

  # TODO: Configure timeout and retry logic (Retriable?)
  def initialize(config = nil)
    @config = config || default_config
    @auth_token = Base64.strict_encode64("#{@config[:email]}:#{@config[:password]}")
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

  private

  def default_config
    {
      url: Rails.configuration.hyacinth['url'],
      email: Rails.configuration.hyacinth['email'],
      password: Rails.configuration.hyacinth['password']
    }
  end

  def connection
    @connection ||= Faraday.new(
      url: @config[:url],
      headers: headers
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
    raise "Invalid JSON response: #{e.message}"
  end
end
