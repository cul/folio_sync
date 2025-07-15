# frozen_string_literal: true

class Folio::Client::JobExecutionManager
  def initialize(folio_client, job_profile_uuid, batch_size)
    @folio_client = folio_client
    @job_profile_uuid = job_profile_uuid
    @batch_size = batch_size
    Rails.logger.debug("JobExecutionManager initialized with profile #{job_profile_uuid}, batch_size #{batch_size}")
  end

  # Executes a complete FOLIO job with the given processed records
  # @param processed_records [Array<Hash>] Array of { marc_record: MARC::Record, metadata: Hash }
  # @return [Folio::Client::JobExecutionSummary] The completed job execution summary
  def execute_job(processed_records)
    Rails.logger.info("Starting FOLIO job execution with #{processed_records.length} records")
    
    # Log metadata for each record
    processed_records.each_with_index do |record, index|
      Rails.logger.debug("Record #{index}: metadata=#{record[:metadata].inspect}")
    end
    
    # Create JobExecution
    job_execution = @folio_client.create_job_execution(
      @job_profile_uuid,
      'MARC',
      processed_records.length,
      @batch_size
    )

    # Add records to JobExecution
    processed_records.each do |processed_record|
      job_execution.add_record(
        processed_record[:marc_record],
        processed_record[:metadata]
      )
    end

    # Start and wait for completion
    job_execution.start
    job_execution_summary = job_execution.wait_until_complete

    Rails.logger.info("Batch completed: #{job_execution_summary.records_processed} records processed")

    job_execution_summary
  end
end
