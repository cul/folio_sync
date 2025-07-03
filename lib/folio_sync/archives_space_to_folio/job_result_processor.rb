# frozen_string_literal: true

module FolioSync
  module ArchivesSpaceToFolio
    class JobResultProcessor
      attr_reader :processing_errors

      def initialize(folio_reader, folio_writer, instance_key)
        @folio_reader = folio_reader
        @folio_writer = folio_writer
        @instance_key = instance_key
        @processing_errors = []
      end

      # Processes job execution results, handling both suppression updates and database record updates
      # @param job_execution_summary [Folio::Client::JobExecutionSummary] The completed job summary
      # @return [Array<FolioSync::Errors::SyncingError>] Any processing errors that occurred
      def process_results(job_execution_summary)
        job_execution_summary.each_result do |_raw_result, custom_metadata, instance_action_status, hrid_list, id_list|
          # Update suppression status for successful records
          update_suppression_status(custom_metadata, id_list) if ['CREATED', 'UPDATED'].include?(instance_action_status)

          # Update database record status
          update_database_record(custom_metadata, instance_action_status, hrid_list)
        end
      end

      private

      # @param custom_metadata [Hash] Metadata containing suppression status and other info
      # Example of custom_metadata:
      # {
      #   repository_key: database_record.repository_key,
      #   resource_key: database_record.resource_key,
      #   hrid: database_record.folio_hrid,
      #   suppress_discovery: database_record.is_folio_suppressed
      # }
      # @param id_list [Array<String>] List of instance record IDs to update,
      # there should be only one ID in this list
      def update_suppression_status(custom_metadata, id_list)
        return if id_list.blank?

        instance_record_id = id_list.first
        incoming_suppress = custom_metadata[:suppress_discovery]

        folio_record = @folio_reader.get_instance_by_id(instance_record_id)
        current_folio_suppress = folio_record['discoverySuppress']

        if current_folio_suppress == incoming_suppress
          Rails.logger.info("No change in suppression status for instance record: #{instance_record_id}")
          return
        end

        data_to_send = build_suppression_update_payload(folio_record, incoming_suppress)
        update_folio_instance_suppression(instance_record_id, data_to_send)
      rescue StandardError => e
        handle_suppression_update_error(custom_metadata, instance_record_id, e)
      end

      # @param custom_metadata [Hash] Metadata containing suppression status and other info
      # Example of custom_metadata:
      # {
      #   repository_key: database_record.repository_key,
      #   resource_key: database_record.resource_key,
      #   hrid: database_record.folio_hrid,
      #   suppress_discovery: database_record.is_folio_suppressed
      # }
      # @param instance_action_status [String] The status of the instance action (e.g., 'CREATED', 'UPDATED', 'DISCARDED')
      # @param hrid_list [Array<String>] List of HRIDs for the instance,
      # there should be only one HRID in this list if the record was created or updated
      def update_database_record(custom_metadata, instance_action_status, hrid_list)
        record = find_local_record(custom_metadata)
        return unless record

        if ['CREATED', 'UPDATED'].include?(instance_action_status)
          update_record_status(record, instance_action_status, hrid_list)
        else
          handle_failed_record(record, instance_action_status)
        end
      end

      def find_local_record(custom_metadata)
        AspaceToFolioRecord.find_by(
          archivesspace_instance_key: @instance_key,
          repository_key: custom_metadata[:repository_key],
          resource_key: custom_metadata[:resource_key]
        )
      end

      # Updates the local record status based on the instance action status
      # Newly created records will have their HRID set and marked for update to ArchivesSpace
      def update_record_status(record, instance_action_status, hrid_list)
        if instance_action_status == 'CREATED' && hrid_list&.any?
          record.update!(folio_hrid: hrid_list.first, pending_update: 'to_aspace')
        else
          record.update!(pending_update: 'no_update')
        end
      end

      def handle_failed_record(record, instance_action_status)
        Rails.logger.warn("Record #{record.id} processing failed with status: #{instance_action_status}")
        processing_error = FolioSync::Errors::SyncingError.new(
          resource_uri: "repositories/#{record[:repository_key]}/resources/#{record[:resource_key]}",
          message: "Failed to create or update record #{record.id}, status: #{instance_action_status}"
        )
        @processing_errors << processing_error
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

      def handle_suppression_update_error(custom_metadata, instance_record_id, error)
        processing_error = FolioSync::Errors::SyncingError.new(
          resource_uri: "repositories/#{custom_metadata[:repository_key]}/resources/#{custom_metadata[:resource_key]}",
          message: "Failed to update suppression status: #{error.message}"
        )
        @processing_errors << processing_error
        Rails.logger.error("Error updating suppression for #{instance_record_id}: #{error.message}")
      end
    end
  end
end
