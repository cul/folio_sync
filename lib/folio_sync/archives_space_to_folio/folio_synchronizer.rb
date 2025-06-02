# frozen_string_literal: true

module FolioSync
  module ArchivesSpaceToFolio
    class FolioSynchronizer
      attr_reader :syncing_errors, :downloading_errors

      ONE_HOUR_IN_SECONDS = 3600

      def initialize(instance_key)
        @logger = Logger.new($stdout)
        @instance_key = instance_key
        @downloading_errors = []
        @syncing_errors = []
      end

      def fetch_and_sync_resources_to_folio(last_x_hours)
        @downloading_errors = []
        @syncing_errors = []
        modified_since = Time.now.utc - (ONE_HOUR_IN_SECONDS * last_x_hours) if last_x_hours

        download_archivesspace_marc_xml(modified_since)
        sync_resources_to_folio
      end

      def download_archivesspace_marc_xml(modified_since)
        exporter = FolioSync::ArchivesSpace::MarcExporter.new(@instance_key)
        exporter.export_recent_resources(modified_since)

        return if exporter.exporting_errors.blank?

        @logger.error("Errors encountered during MARC XML download: #{exporter.exporting_errors}")
        @downloading_errors = exporter.exporting_errors
      end

      def sync_resources_to_folio
        # Iterate over all files in the directory specified in the folio_sync.yml
        # Use foreach for better performance with large directories
        folio_writer = FolioSync::Folio::Writer.new

        config = Rails.configuration.folio_sync[:aspace_to_folio]
        downloads_dir = File.join(config[:marc_download_base_directory], @instance_key)

        Dir.foreach(downloads_dir) do |file|
          next if ['.', '..'].include?(file)

          begin
            Rails.logger.debug "Processing file: #{file}"

            bib_id = File.basename(file, '.xml')
            enhancer = FolioSync::ArchivesSpaceToFolio::MarcRecordEnhancer.new(bib_id, @instance_key)
            enhancer.enhance_marc_record!
            marc_record = enhancer.marc_record

            folio_writer.create_or_update_folio_record(marc_record)
          rescue StandardError => e
            @logger.error("Error syncing resources to FOLIO: #{e.message}")
            @syncing_errors << FolioSync::Errors::SyncingError.new(
              bib_id: bib_id,
              message: e.message
            )
          end
        end
      end
    end
  end
end
