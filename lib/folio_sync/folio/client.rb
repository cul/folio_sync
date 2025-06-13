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

  def create_job_execution(job_type_uuid, data_type, number_of_expected_records, batch_size)
    Folio::Client::JobExecution.new(self, job_type_uuid, data_type, number_of_expected_records, batch_size)
  end
end
