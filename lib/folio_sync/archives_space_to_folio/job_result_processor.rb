# frozen_string_literal: true

module FolioSync
  module ArchivesSpaceToFolio
    class JobResultProcessor
      attr_reader :processing_errors

      def initialize(folio_reader, folio_writer, instance_key)
        @folio_reader = folio_reader
        @folio_writer = folio_writer
        @instance_key = instance_key
        @holdings_creator = FolioSync::Folio::HoldingsCreator.new(@folio_writer)
        @processing_errors = []
        Rails.logger.debug("JobResultProcessor initialized for instance #{instance_key}")
      end

      # Processes job execution results, handling both suppression updates and database record updates
      # @param job_execution_summary [Folio::Client::JobExecutionSummary] The completed job summary
      # @return [Array<FolioSync::Errors::SyncingError>] Any processing errors that occurred
      def process_results(job_execution_summary)
        Rails.logger.info('Processing job execution results')
        result_count = 0

        job_execution_summary.each_result do |_raw_result, custom_metadata, instance_action_status, hrid_list, id_list|
          result_count += 1
          Rails.logger.debug("Processing result #{result_count}: status=#{instance_action_status}, " \
                            "hrid_list=#{hrid_list}, id_list=#{id_list}, metadata=#{custom_metadata.inspect}")

          # Update suppression status for successful records
          if ['CREATED', 'UPDATED'].include?(instance_action_status)
            Rails.logger.debug("Record was #{instance_action_status}, updating suppression status")
            update_suppression_status(custom_metadata, id_list)
          else
            Rails.logger.warn("Record has status #{instance_action_status}, skipping suppression update")
          end

          # Create holdings record for newly created instances
          if instance_action_status == 'CREATED' && id_list&.any?
            instance_id = id_list.first
            Rails.logger.debug("Creating holdings record for newly created instance: #{instance_id}")
            create_holdings_record_for_instance(custom_metadata, instance_id)
          end

          # Update database record status
          update_database_record(custom_metadata, instance_action_status, hrid_list)
        end

        Rails.logger.info("Processed #{result_count} results. Errors: #{@processing_errors.length}")
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
        if id_list.blank?
          Rails.logger.warn('No instance IDs provided for suppression update')
          return
        end

        instance_record_id = id_list.first
        incoming_suppress = custom_metadata[:suppress_discovery]

        Rails.logger.debug("Checking suppression status for instance #{instance_record_id}")

        folio_record = @folio_reader.get_instance_by_id(instance_record_id)
        current_folio_suppress = folio_record['discoverySuppress']

        if current_folio_suppress == incoming_suppress
          Rails.logger.info("No change in suppression status for instance record: #{instance_record_id} " \
                           "(current=#{current_folio_suppress}, incoming=#{incoming_suppress})")
          return
        end

        Rails.logger.info("Updating suppression status for instance #{instance_record_id}: " \
                         "#{current_folio_suppress} -> #{incoming_suppress}")

        data_to_send = build_suppression_update_payload(folio_record, incoming_suppress)
        update_folio_instance_suppression(instance_record_id, data_to_send)
      rescue StandardError => e
        handle_suppression_update_error(custom_metadata, instance_record_id, e)
      end

      def create_holdings_record_for_instance(custom_metadata, instance_id)
        @holdings_creator.create_holdings_for_instance(instance_id, {
          holdings_call_number: custom_metadata[:holdings_call_number],
          permanent_location: custom_metadata[:permanent_location]
        })
      rescue StandardError => e
        Rails.logger.error("Holdings creation failed: #{e.message}")
        processing_error = FolioSync::Errors::SyncingError.new(
          resource_uri: "repositories/#{custom_metadata[:repository_key]}/resources/#{custom_metadata[:resource_key]}",
          message: "Holdings creation failed for instance #{instance_id}: #{e.message}"
        )
        @processing_errors << processing_error
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
        Rails.logger.debug(
          "Updating database record: status=#{instance_action_status}, metadata=#{custom_metadata.inspect}"
        )

        record = find_local_record(custom_metadata)
        if record.nil?
          Rails.logger.error("Could not find local record for repo=#{custom_metadata[:repository_key]}, " \
                            "resource=#{custom_metadata[:resource_key]}")
          return
        end

        if ['CREATED', 'UPDATED'].include?(instance_action_status)
          update_record_status(record, instance_action_status, hrid_list)
        else
          handle_failed_record(record, instance_action_status)
        end
      end

      def find_local_record(custom_metadata)
        Rails.logger.debug("Finding local record: instance=#{@instance_key}, " \
                          "repo=#{custom_metadata[:repository_key]}, resource=#{custom_metadata[:resource_key]}")
        AspaceToFolioRecord.find_by(
          archivesspace_instance_key: @instance_key,
          repository_key: custom_metadata[:repository_key],
          resource_key: custom_metadata[:resource_key]
        )
      end

      # Updates the local record status based on the instance action status
      # Newly created records will have their HRID set and marked for update to ArchivesSpace
      def update_record_status(record, instance_action_status, hrid_list)
        Rails.logger.debug("Updating record status for record #{record.id}: status=#{instance_action_status}")

        if instance_action_status == 'CREATED' && hrid_list&.any?
          Rails.logger.info("Record #{record.id} was CREATED with HRID #{hrid_list.first}, marking for ASpace update")
          record.update!(folio_hrid: hrid_list.first, pending_update: 'to_aspace')
        else
          Rails.logger.info("Record #{record.id} was #{instance_action_status}, marking as no_update")
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
        payload = {
          'discoverySuppress' => incoming_suppress,
          'title' => folio_record['title'],
          'source' => 'MARC',
          'instanceTypeId' => folio_record['instanceTypeId'],
          'hrid' => folio_record['hrid'],
          '_version' => folio_record['_version']
        }
        Rails.logger.debug("Built suppression update payload: #{payload.inspect}")
        payload
      end

      def update_folio_instance_suppression(instance_record_id, data_to_send)
        Rails.logger.debug("Sending suppression update to FOLIO for instance #{instance_record_id}")
        @folio_writer.update_instance_record(instance_record_id, data_to_send)
        Rails.logger.info("Successfully updated suppression status for instance: #{instance_record_id}")
      end

      def handle_suppression_update_error(custom_metadata, instance_record_id, error)
        Rails.logger.error(
          "Error updating suppression for #{instance_record_id}: #{error.class.name}: #{error.message}"
        )

        processing_error = FolioSync::Errors::SyncingError.new(
          resource_uri: "repositories/#{custom_metadata[:repository_key]}/resources/#{custom_metadata[:resource_key]}",
          message: "Failed to update suppression status: #{error.message}"
        )
        @processing_errors << processing_error
      end
    end
  end
end
