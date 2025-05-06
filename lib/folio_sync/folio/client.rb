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

  def create_or_update_folio_record(bibid)
    folio_marc = get_marc_record(bibid)

    if folio_marc
      update_existing_folio_marc_record(bibid, folio_marc)
    else
      create_new_folio_marc_record(bibid)
    end
  end

  # If the record doesn't exist in FOLIO, create a new one
  def create_new_folio_marc_record(bibid)
    # TODO: Should also update 035 field
    marc_record = FolioSync::Folio::MarcRecord.new(bibid)
    marc_record.process_record

    # TODO: Call the FOLIO API to create a new record
  end

  # If the record already exists in FOLIO, update it
  def update_existing_folio_marc_record(bibid, folio_marc)
    marc_record = FolioSync::Folio::MarcRecord.new(bibid, folio_marc)
    marc_record.process_record

    # TODO: Call the FOLIO API to update the record
  end

  private

  def handle_response(response, error_message)
    raise FolioSync::Exceptions::FolioRequestError, "#{error_message}: #{response}" unless response['status'] == 'ok'

    response.parsed
  end
end
