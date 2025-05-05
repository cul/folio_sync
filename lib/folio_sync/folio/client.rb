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
    response # Returns Marc::Record
  end

  def create_or_update_folio_record(bibid)
    folio_marc = get_marc_record(bibid)

    if folio_marc
      puts "FOLIO MARC record exists for bibid: #{bibid}"
      update_existing_folio_marc_record(bibid, folio_marc)
    else
      puts "FOLIO MARC record doesn't exist for bibid: #{bibid}"
      return
      create_new_folio_marc_record(bibid)
    end
  end

  # If the record doesn't exist in FOLIO, create a new one
  def create_new_folio_marc_record(bibid)
    # process_record + update 035 field

    # TODO: Call the FOLIO API to create a new record
  end

  # If the record already exists in FOLIO, update it
  def update_existing_folio_marc_record(bibid, folio_marc)
    marc_record = FolioSync::Folio::TestRecord.new(bibid, folio_marc)
    updated_record = marc_record.process_record

    # TODO: Call the FOLIO API to update the record
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