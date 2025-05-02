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

  def get_marc_record(hrid)
    response = self.find_marc_record(instance_record_hrid: hrid)

    # This response returns Marc::Record
    response
  end

  def create_updated_marc_record(bib_id, folio_marc)
    updated_marc = FolioSync::Folio::MarcRecord.new(bib_id, folio_marc)

    # TODO: Implement the logic to update the FOLIO MARC record
  end

  private

  def handle_response(response, error_message)
    unless response['status'] == 'ok'
      # TODO: Raise an exception
      # puts "#{error_message}: #{response}"
      raise FolioSync::Exceptions::FolioRequestError, "#{error_message}: #{response}"
    end

    response.parsed
  end
end