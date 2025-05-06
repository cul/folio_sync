# frozen_string_literal: true

class FolioSync::Folio::Client < FolioApiClient
  def self.instance
    @instance ||= self.new(
      FolioApiClient::Configuration.new(
        url: Rails.configuration.folio['base_url'],
        username: Rails.configuration.folio['username'],
        password: Rails.configuration.folio['password'],
        tenant: Rails.configuration.folio['tenant'],
        timeout: Rails.configuration.folio['timeout']
      )
    )
    @instance
  end

  def check_health
    self.get('/admin/health')
  end

  # @param hrid [String] The HRID (BIBID) of the instance record to fetch.
  def get_marc_record(hrid)
    # Returns Marc::Record
    self.find_marc_record(instance_record_hrid: hrid)
  end

  def create_or_update_folio_record(marc_record)
    # TODO: Call the FOLIO API to create/update a record
  end

  private

  def handle_response(response, error_message)
    raise FolioSync::Exceptions::FolioRequestError, "#{error_message}: #{response}" unless response['status'] == 'ok'

    response.parsed
  end
end
