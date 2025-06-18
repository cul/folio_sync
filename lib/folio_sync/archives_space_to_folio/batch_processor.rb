# frozen_string_literal: true

module FolioSync
  module Errors
    class ProcessingError
      attr_reader :resource_uri, :message

      def initialize(resource_uri:, message:)
        @resource_uri = resource_uri
        @message = message
      end

      def to_s
        "Processing Error - URI: #{resource_uri}, Message: #{message}"
      end
    end

    class BatchError
      attr_reader :batch_size, :message

      def initialize(batch_size:, message:)
        @batch_size = batch_size
        @message = message
      end

      def to_s
        "Batch Error - Size: #{batch_size}, Message: #{message}"
      end
    end
  end

  module ArchivesSpaceToFolio
    class BatchProcessor
      attr_reader :batch_errors, :processing_errors

      DEFAULT_BATCH_SIZE = 50
      DEFAULT_JOB_PROFILE_UUID = '3fe97378-297c-40d9-9b42-232510afc58f' # ArchivesSpace to FOLIO job profile

      def initialize(instance_key)
        @instance_key = instance_key
        @batch_errors = []
        @processing_errors = []
        @folio_client = FolioSync::Folio::Client.instance
        @record_processor = RecordProcessor.new(instance_key)
      end

      # Processes records in batches and sends them to FOLIO
      # Accepts a collection of AspaceToFolioRecord objects
      def process_records(records)
        records.in_batches(of: batch_size) do |batch|
          process_batch(batch)
        end

        @processing_errors.concat(@record_processor.processing_errors)
      end

      private

      def process_batch(records_batch)
        Rails.logger.info("Processing batch of #{records_batch.count} records")
        
        # Process each record to get enhanced MARC + metadata
        processed_records = []
        records_batch.each do |record|
          processed_record = @record_processor.process_record(record)
          processed_records << processed_record if processed_record
        end

        return if processed_records.empty?

        # Submit batch to FOLIO
        submit_batch_to_folio(processed_records)
      rescue StandardError => e
        error = FolioSync::Errors::BatchError.new(
          batch_size: records_batch.count,
          message: "Failed to process batch: #{e.message}"
        )
        @batch_errors << error
        Rails.logger.error("Error processing batch: #{e.message}")
      end

      def submit_batch_to_folio(processed_records)
        # Create JobExecution
        job_execution = @folio_client.create_job_execution(
          job_profile_uuid,
          'MARC',
          processed_records.length,
          batch_size
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

        # Update database records based on results
        update_records_from_results(job_execution_summary)
        
        Rails.logger.info("Batch completed: #{job_execution_summary.records_processed} records processed")
      end

      def update_records_from_results(job_execution_summary)
        job_execution_summary.each_result do |raw_result, custom_metadata, instance_action_status, hrid_list|
          next unless custom_metadata[:aspace_record_id]

          record = AspaceToFolioRecord.find(custom_metadata[:aspace_record_id])
          
          if instance_action_status == 'CREATED' || instance_action_status == 'UPDATED'
            # Update the record with new HRID if it was a create operation
            if instance_action_status == 'CREATED' && hrid_list&.any?
              record.update!(folio_hrid: hrid_list.first, pending_update: 'to_aspace')
            else
              record.update!(pending_update: 'no_update')
            end
          else
            Rails.logger.warn("Record #{record.id} processing failed with status: #{instance_action_status}")
          end
        end
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