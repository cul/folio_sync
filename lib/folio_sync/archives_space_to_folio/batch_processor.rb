# frozen_string_literal: true

module FolioSync
  module Errors
    class ProcessingError
      attr_reader :resource_uri, :message

      def initialize(resource_uri:, message:)
        @resource_uri = resource_uri
        @message = message
      end
    end

    class BatchError
      attr_reader :batch_size, :message

      def initialize(batch_size:, message:)
        @batch_size = batch_size
        @message = message
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
        @folio_reader = FolioSync::Folio::Reader.new
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

        # Update suppression status based on results
        update_suppression_status(job_execution_summary)

        # Update database records based on results
        update_records_from_results(job_execution_summary)

        Rails.logger.info("Batch completed: #{job_execution_summary.records_processed} records processed")
      end

      def update_records_from_results(job_execution_summary)
        job_execution_summary.each_result do |_raw_result, custom_metadata, instance_action_status, hrid_list, _id_list|
          record = find_local_record(custom_metadata)

          if ['CREATED', 'UPDATED'].include?(instance_action_status)
            update_record_status(record, instance_action_status, hrid_list)
          else
            handle_failed_record(record, instance_action_status)
          end
        end
      end

      def update_suppression_status(job_execution_summary)
        job_execution_summary.each_result do |_raw_result, custom_metadata, instance_action_status, _hrid_list, id_list|
          next unless ['CREATED', 'UPDATED'].include?(instance_action_status)

          instance_record_id = id_list.first
          incoming_suppress = custom_metadata[:suppress_discovery]

          begin
            folio_record = @folio_reader.get_instance_by_id(instance_record_id)
            current_folio_suppress = folio_record['discoverySuppress']

            unless should_update_suppression?(current_folio_suppress, incoming_suppress)
              Rails.logger.info("No change in suppression status for instance record: #{instance_record_id}")
              next
            end

            data_to_send = build_suppression_update_payload(folio_record, incoming_suppress)
            update_folio_instance_suppression(instance_record_id, data_to_send)
          rescue StandardError => e
            handle_suppression_update_error(custom_metadata, instance_record_id, e)
          end
        end
      end

      def batch_size
        Rails.configuration.folio_sync.dig(:aspace_to_folio, :batch_size) || DEFAULT_BATCH_SIZE
      end

      def job_profile_uuid
        Rails.configuration.folio_sync.dig(:aspace_to_folio, :job_profile_uuid) || DEFAULT_JOB_PROFILE_UUID
      end

      # TODO: Add it as a class method on AspaceToFolioRecord model
      def find_local_record(custom_metadata)
        AspaceToFolioRecord.find_by(
          archivesspace_instance_key: @instance_key,
          repository_key: custom_metadata[:repository_key],
          resource_key: custom_metadata[:resource_key]
        )
      end

      def update_record_status(record, instance_action_status, hrid_list)
        if instance_action_status == 'CREATED' && hrid_list&.any?
          record.update!(folio_hrid: hrid_list.first, pending_update: 'to_aspace')
        else
          record.update!(pending_update: 'no_update')
        end
      end

      def handle_failed_record(record, instance_action_status)
        Rails.logger.warn("Record #{record.id} processing failed with status: #{instance_action_status}")
      end

      def build_suppression_update_payload(folio_record, incoming_suppress)
        {
          'discoverySuppress' => incoming_suppress,
          'title' => folio_record['title'],
          'source' => 'MARC',
          'instanceTypeId' => folio_record['instanceTypeId'],
          'hrid' => folio_record['hrid'],
          '_version' => folio_record['_version']
        }
      end

      def update_folio_instance_suppression(instance_record_id, data_to_send)
        @folio_writer.update_instance_record(instance_record_id, data_to_send)
        Rails.logger.debug("Updated suppression status for sourceRecordId: #{instance_record_id}")
      end

      def should_update_suppression?(current, incoming)
        current != incoming
      end

      def handle_suppression_update_error(custom_metadata, instance_record_id, error)
        processing_error = FolioSync::Errors::ProcessingError.new(
          resource_uri: "repositories/#{custom_metadata[:repository_key]}/resources/#{custom_metadata[:resource_key]}",
          message: "Failed to update suppression status: #{error.message}"
        )
        @processing_errors << processing_error
        Rails.logger.error("Error updating suppression for #{instance_record_id}: #{error.message}")
      end
    end
  end
end
