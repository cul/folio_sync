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
        @folio_writer = FolioSync::Folio::Writer.new
        @record_processor = RecordProcessor.new(instance_key)
      end

      # Processes records in batches and sends them to FOLIO
      # @param records [ActiveRecord::Relation] Collection of AspaceToFolioRecord objects
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
        puts "Submitting batch of #{processed_records.length} records to FOLIO"
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
        update_suppression_status(job_execution_summary)
        update_records_from_results(job_execution_summary)

        Rails.logger.info("Batch completed: #{job_execution_summary.records_processed} records processed")
      end

      def update_records_from_results(job_execution_summary)
        job_execution_summary.each_result do |_raw_result, custom_metadata, instance_action_status, hrid_list, _id_list|
          puts "Processing result for custom metadata: #{custom_metadata.inspect}, status: #{instance_action_status}"

          record = AspaceToFolioRecord.find_by(
            archivesspace_instance_key: @instance_key,
            repository_key: custom_metadata[:repository_key],
            resource_key: custom_metadata[:resource_key]
          )
          puts "Found record: #{record.inspect}"

          if ['CREATED', 'UPDATED'].include?(instance_action_status)
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

      def update_suppression_status(job_execution_summary)
        job_execution_summary.each_result do |raw_result, custom_metadata, instance_action_status, hrid_list, id_list|
          puts "Raw result: #{raw_result.inspect}"
          puts "custom metadata: #{custom_metadata.inspect}"

          puts '----'
          puts "Found my instance id #{id_list.first}"

          return
          # Only update suppression for successfully processed records
          next unless ['CREATED', 'UPDATED'].include?(instance_action_status)
          next unless raw_result['sourceRecordId']

          source_record_id = raw_result['sourceRecordId']
          suppress_discovery = custom_metadata[:suppress_discovery]

          begin
            @folio_writer.suppress_instance_from_discovery(id_list.first, suppress_discovery)
            Rails.logger.debug("Updated suppression status for sourceRecordId: #{source_record_id}")
          rescue StandardError => e
            error = FolioSync::Errors::ProcessingError.new(
              resource_uri:
                "repositories/#{custom_metadata[:repository_key]}/resources/#{custom_metadata[:resource_key]}",
              message: "Failed to update suppression status: #{e.message}"
            )
            @processing_errors << error
            Rails.logger.error("Error updating suppression for #{source_record_id}: #{e.message}")
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
