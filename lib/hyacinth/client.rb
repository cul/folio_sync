# frozen_string_literal: true

class Hyacinth::Client
  def self.instance
    @instance ||= self.new(
      Hyacinth::Configuration.new(
        url: Rails.configuration.hyacinth['url'],
        email: Rails.configuration.hyacinth['email'],
        password: Rails.configuration.hyacinth['password']
      )
    )
    @hyacinth_basic_auth_token = Base64.strict_encode64("#{@instance.email}:#{@instance.password}")

    # @instance
  end

  def headers_for_connection
    {
      'Accept': 'application/json, text/plain',
      'Content-Type': 'application/json'
    }
  end

  def connection
    @connection ||= Faraday.new(
      headers: headers_for_connection,
      url: Rails.configuration.hyacinth['url']
    ) do |faraday|
      faraday.adapter Faraday.default_adapter
      faraday.use Faraday::Response::RaiseError
    end
  end
end
