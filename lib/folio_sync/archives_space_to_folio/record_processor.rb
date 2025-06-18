# frozen_string_literal: true

module FolioSync
  module ArchivesSpaceToFolio
    class RecordProcessor
      attr_reader :processing_errors

      def initialize(instance_key)
        @instance_key = instance_key
        @processing_errors = []
      end

      # Processes a single AspaceToFolioRecord and returns enhanced MARC with metadata
      # @param record [AspaceToFolioRecord] The record to process
      # @return [Hash, nil] Returns { marc_record: MARC::Record, metadata: Hash } or nil if processing failed
      def process_record(record)
        config = Rails.configuration.folio_sync[:aspace_to_folio]

        aspace_marc_path = File.join(config[:marc_download_base_directory], record.archivesspace_marc_xml_path)
        folio_marc_path = nil

        if record.folio_hrid.present?
          folio_marc_path = File.join(config[:marc_download_base_directory], record.folio_marc_xml_path)
        end

        # Enhance the MARC record
        enhancer = MarcRecordEnhancer.new(aspace_marc_path, folio_marc_path, record.folio_hrid, @instance_key)
        enhanced_marc = enhancer.enhance_marc_record!

        # Prepare metadata for FOLIO JobExecution
        metadata = {
          repository_key: record.repository_key,
          resource_key: record.resource_key,
          hrid: record.folio_hrid,
          suppress_discovery: record.is_folio_suppressed
        }

        { marc_record: enhanced_marc, metadata: metadata }
      rescue StandardError => e
        error = FolioSync::Errors::ProcessingError.new(
          resource_uri: "repositories/#{record.repository_key}/resources/#{record.resource_key}",
          message: "Failed to process record: #{e.message}"
        )
        @processing_errors << error
        Rails.logger.error("Error processing record #{record.id}: #{e.message}")
        nil
      end
    end
  end
end
