# frozen_string_literal: true

class Folio::Client::JobExecutionManager
  def initialize(folio_client, job_profile_uuid, total_number_of_records, batch_size)
    @folio_client = folio_client
    @job_profile_uuid = job_profile_uuid
    # Create JobExecution
    @job_execution = @folio_client.create_job_execution(
      @job_profile_uuid,
      'MARC',
      total_number_of_records,
      batch_size
    )
  end

  # Adds the given processed records to the JobExecution that we are setting up.
  # @param processed_records [Array<Hash>] Array of { marc_record: MARC::Record, metadata: Hash }
  def add_records(processed_records)
    # Add records to JobExecution
    processed_records.each do |processed_record|
      @job_execution.add_record(
        processed_record[:marc_record],
        processed_record[:metadata]
      )
    end
  end

  # Executes a complete FOLIO job with all of the processed records previously added through the #add_records method.
  # @return [Folio::Client::JobExecutionSummary] The completed job execution summary
  def execute_job
    # Start and wait for completion
    @job_execution.start
    job_execution_summary = @job_execution.wait_until_complete

    Rails.logger.info("Batch completed: #{job_execution_summary.records_processed} records processed")

    job_execution_summary
  end
end
