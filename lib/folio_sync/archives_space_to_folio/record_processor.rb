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
        aspace_marc_path, folio_marc_path = resolve_marc_paths(record)
        enhanced_marc = create_enhanced_marc(aspace_marc_path, folio_marc_path, record.folio_hrid)
        metadata = build_metadata(record)

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

      def create_enhanced_marc(aspace_marc_path, folio_marc_path, folio_hrid)
        enhancer = MarcRecordEnhancer.new(aspace_marc_path, folio_marc_path, folio_hrid, @instance_key)
        enhancer.enhance_marc_record!
      end

      def resolve_marc_paths(record)
        config = Rails.configuration.folio_sync[:aspace_to_folio]
        aspace_marc_path = File.join(config[:marc_download_base_directory], record.archivesspace_marc_xml_path)
        folio_marc_path = if record.folio_hrid.present?
                            File.join(config[:marc_download_base_directory],
                                      record.folio_marc_xml_path)
                          end
        [aspace_marc_path, folio_marc_path]
      end

      # Preserve some of the data that cannot be sent in a MARC record
      # To use later when updating the record back in ArchivesSpace
      def build_metadata(record)
        {
          repository_key: record.repository_key,
          resource_key: record.resource_key,
          hrid: record.folio_hrid,
          suppress_discovery: record.is_folio_suppressed
        }
      end
    end
  end
end
