# frozen_string_literal: true

class FolioSync::Folio::Client < FolioApiClient
  def self.instance
    unless @instance
      @instance = self.new(
        FolioApiClient::Configuration.new(
          url: Rails.configuration.folio['base_url'],
          username: Rails.configuration.folio['username'],
          password: Rails.configuration.folio['password'],
          tenant: Rails.configuration.folio['tenant'],
          timeout: Rails.configuration.folio['timeout']
        )
      )

      @instance.refresh_auth_token! # Ensure the client is authenticated
    end
    @instance
  end

  def check_health
    response = self.get('/admin/health')
    handle_response(response, 'Error checking FOLIO health')
  end

  private

  def handle_response(response, error_message)
    unless response['status'] == 'ok'
      # TODO: Raise an exception
      puts "#{error_message}: #{response}"
    end

    response
  end
end