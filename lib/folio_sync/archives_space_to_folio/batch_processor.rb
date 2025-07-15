# frozen_string_literal: true

module FolioSync
  module ArchivesSpaceToFolio
    class BatchProcessor
      attr_reader :syncing_errors

      DEFAULT_BATCH_SIZE = 50
      DEFAULT_JOB_PROFILE_UUID = '3fe97378-297c-40d9-9b42-232510afc58f' # ArchivesSpace to FOLIO job profile

      def initialize(instance_key)
        @instance_key = instance_key
        @syncing_errors = []
        @folio_client = FolioSync::Folio::Client.instance
        @folio_reader = FolioSync::Folio::Reader.new
        @folio_writer = FolioSync::Folio::Writer.new
        @record_processor = RecordProcessor.new(instance_key)
        Rails.logger.info("BatchProcessor initialized for instance #{instance_key}")
      end

      # Processes records in batches and sends them to FOLIO
      # @param records [ActiveRecord::Relation] Collection of AspaceToFolioRecord objects
      def process_records(records)
        total_records = records.count
        Rails.logger.info("Starting batch processing of #{total_records} records")
        batch_count = 0
        
        records.in_batches(of: batch_size) do |batch|
          batch_count += 1
          Rails.logger.info("Processing batch #{batch_count} with #{batch.count} records")
          process_batch(batch)
        end

        @syncing_errors.concat(@record_processor.processing_errors)
        Rails.logger.info("Batch processing complete. Total errors: #{@syncing_errors.length}")
      end

      private

      def process_batch(records_batch)
        Rails.logger.info("Processing batch of #{records_batch.count} records")
        
        # Log details about each record in the batch
        records_batch.each do |record|
          Rails.logger.debug("Batch contains record: repo=#{record.repository_key}, " \
                            "resource=#{record.resource_key}, hrid=#{record.folio_hrid}, " \
                            "pending_update=#{record.pending_update}")
        end

        # Process each record to get enhanced MARC + metadata
        processed_records = []
        records_batch.each do |record|
          processed_record = @record_processor.process_record(record)
          processed_records << processed_record if processed_record
        end

        Rails.logger.info("Successfully processed #{processed_records.length}/#{records_batch.count} records in batch")

        return if processed_records.empty?

        submit_batch_to_folio(processed_records)
      rescue StandardError => e
        Rails.logger.error("Error processing batch: #{e.class.name}: #{e.message}")
        Rails.logger.error(e.backtrace.first(5).join("\n"))
        error = FolioSync::Errors::SyncingError.new(
          message: "Failed to process a batch of #{records_batch.count} records: #{e.message}"
        )
        @syncing_errors << error
      end

      def submit_batch_to_folio(processed_records)
        Rails.logger.info("Submitting batch of #{processed_records.length} records to FOLIO")
        
        # Execute the FOLIO job
        # Use the :: prefix to avoid namespace issues
        job_manager = ::Folio::Client::JobExecutionManager.new(@folio_client, job_profile_uuid, batch_size)
        job_execution_summary = job_manager.execute_job(processed_records)

        Rails.logger.info("FOLIO job execution completed. Processing results...")
        
        # Process the results (suppression updates and database record updates)
        result_processor = FolioSync::ArchivesSpaceToFolio::JobResultProcessor.new(@folio_reader, @folio_writer, @instance_key)
        result_processor.process_results(job_execution_summary)

        job_result_errors = result_processor.processing_errors
        if job_result_errors.any?
          Rails.logger.warn("Result processor reported #{job_result_errors.length} errors")
        end
        @syncing_errors.concat(job_result_errors)
      end

      def batch_size
        Rails.configuration.folio_sync.dig(:aspace_to_folio, :batch_size) || DEFAULT_BATCH_SIZE
      end

      def job_profile_uuid
        Rails.configuration.folio_sync.dig(:aspace_to_folio, :job_profile_uuid) || DEFAULT_JOB_PROFILE_UUID
      end
    end
  end
end
