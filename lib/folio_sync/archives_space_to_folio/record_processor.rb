# frozen_string_literal: true

module FolioSync
  module ArchivesSpaceToFolio
    class RecordProcessor
      attr_reader :processing_errors

      def initialize(instance_key)
        @instance_key = instance_key
        @processing_errors = []
        Rails.logger.debug("RecordProcessor initialized for instance #{instance_key}")
      end

      # Processes a single AspaceToFolioRecord and returns enhanced MARC with metadata
      # @param record [AspaceToFolioRecord] The record to process
      # @return [Hash, nil] Returns { marc_record: MARC::Record, metadata: Hash } or nil if processing failed
      def process_record(record)
        Rails.logger.debug("Processing record #{record.id}: repo=#{record.repository_key}, " \
                          "resource=#{record.resource_key}, hrid=#{record.folio_hrid}")

        enhanced_marc = load_marc_record(record.prepared_folio_marc_path)
        permanent_location = enhanced_marc['049']['a'] # todo: error handling

        metadata = build_metadata(record, permanent_location)

        Rails.logger.debug("Successfully processed record #{record.id} with metadata: #{metadata.inspect}")
        { marc_record: enhanced_marc, metadata: metadata }
      rescue StandardError => e
        error = FolioSync::Errors::SyncingError.new(
          resource_uri: "repositories/#{record.repository_key}/resources/#{record.resource_key}",
          message: "Failed to process record: #{e.message}"
        )
        @processing_errors << error
        Rails.logger.error("Error processing record #{record.id}: #{e.message}")
        nil
      end

      private

      # Preserve some of the data that cannot be sent in a MARC record
      # To use later when updating the record back in ArchivesSpace
      def build_metadata(record, permanent_location)
        {
          repository_key: record.repository_key,
          resource_key: record.resource_key,
          hrid: record.folio_hrid,
          suppress_discovery: record.is_folio_suppressed,
          holdings_call_number: record.holdings_call_number,
          permanent_location: permanent_location
        }
      end

      def load_marc_record(marc_file_path)
        raise "MARC file not found: #{marc_file_path}" unless File.exist?(marc_file_path)

        MARC::Reader.new(marc_file_path).first
      end
    end
  end
end
