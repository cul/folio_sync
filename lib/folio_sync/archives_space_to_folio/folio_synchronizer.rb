# frozen_string_literal: true

module FolioSync
  module ArchivesSpaceToFolio
    class FolioSynchronizer
      attr_reader :syncing_errors, :downloading_errors

      ONE_DAY_IN_SECONDS = 24 * 60 * 60

      def initialize
        @logger = Logger.new($stdout)
        @downloading_errors = []
        @syncing_errors = []
      end

      def fetch_and_sync_resources_to_folio
        @downloading_errors = []
        @syncing_errors = []
        last_24_hours = Time.now.utc - ONE_DAY_IN_SECONDS

        download_archivesspace_marc_xml(last_24_hours)
        sync_resources_to_folio
      end

      def download_archivesspace_marc_xml(modified_since)
        exporter = FolioSync::ArchivesSpace::MarcExporter.new
        exporter.export_recent_resources(modified_since)

        if exporter.exporting_errors.present?
          @logger.error("Errors encountered during MARC XML download: #{exporter.exporting_errors}")
          @downloading_errors = exporter.exporting_errors
        end
      end

      def sync_resources_to_folio
        # Iterate over all files in the tmp/marc_files directory
        # Use foreach for better performance with large directories
        marc_dir = Rails.root.join('tmp/marc_files')
        folio_writer = FolioSync::Folio::Writer.new

        Dir.foreach(marc_dir) do |file|
          next if ['.', '..'].include?(file)
          bib_id = File.basename(file, '.xml')

          begin
            Rails.logger.debug "Processing file: #{file}"

            enhancer = FolioSync::ArchivesSpaceToFolio::MarcRecordEnhancer.new(bib_id)
            enhancer.enhance_marc_record!
            marc_record = enhancer.marc_record

            folio_writer.create_or_update_folio_record(marc_record)
          rescue => e
            @logger.error("Error syncing resources to FOLIO: #{e.message}")
            @syncing_errors << {
              bib_id: bib_id,
              error: e.message
            }
          end
        end
      end
    end
  end
end
