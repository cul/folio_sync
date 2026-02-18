# frozen_string_literal: true

module FolioSync
  module FolioToHyacinth
    class HyacinthRecordWriter
      attr_reader :syncing_errors

      def initialize
        @logger = Logger.new($stdout)
        @client = FolioSync::Hyacinth::Client.instance
        @syncing_errors = []
      end

      # @param [String] marc_file_path
      # @param [String] folio_hrid
      # @param [Array] existing_records
      def sync(marc_file_path, folio_hrid, existing_records)
        case existing_records.length
        when 0
          create_new_record(marc_file_path, folio_hrid)
        when 1
          update_existing_record(marc_file_path, folio_hrid, existing_records.first)
        else
          handle_multiple_records(folio_hrid)
        end
      end

      private

      def create_new_record(marc_file_path, folio_hrid)
        @logger.info("Creating new Hyacinth record for #{folio_hrid}")

        new_record = FolioToHyacinthRecord.new(marc_file_path)
        response = @client.create_new_record(new_record.digital_object_data, publish: true)

        @logger.info("Created record for #{folio_hrid}: #{response.inspect}")
      rescue StandardError => e
        error_message = "Failed to create record for #{folio_hrid}: #{e.message}"
        @logger.error(error_message)
        @syncing_errors << error_message
      end

      def update_existing_record(marc_file_path, folio_hrid, existing_record)
        @logger.info("Updating existing Hyacinth record for #{folio_hrid}")
        preserved_data = { 'identifiers' => existing_record['identifiers'] }
        updated_record = FolioToHyacinthRecord.new(marc_file_path, preserved_data)

        response = @client.update_existing_record(
          existing_record['pid'],
          updated_record.digital_object_data,
          publish: true
        )

        @logger.info("Updated record #{existing_record['pid']}: #{response.inspect}")
      rescue StandardError => e
        error_message = "Failed to update record #{existing_record['pid']} for #{folio_hrid}: #{e.message}"
        @logger.error(error_message)
        @syncing_errors << error_message
      end

      def handle_multiple_records(folio_hrid)
        error_message = "Multiple Hyacinth records found for FOLIO HRID #{folio_hrid}"
        @logger.error(error_message)
        @syncing_errors << error_message
      end
    end
  end
end
