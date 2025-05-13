# frozen_string_literal: true

module FolioSync
  module ArchivesSpaceToFolio
    class FolioSynchronizer
      # temporary error classes for testing
      class DownloadError < StandardError; end
      class SyncError < StandardError; end

      attr_reader :syncing_errors, :downloading_errors
      ONE_DAY_IN_SECONDS = 24 * 60 * 60

      def initialize
        @logger = Logger.new($stdout)
        @downloading_errors = ["Error downloading MARC XML for resource id: 4", "Error downloading MARC XML for resource id: 7"]
        @syncing_errors = ["Error syncing MARC XML for resource id: 4", "Error syncing MARC XML for resource id: 7"]
      end

      def fetch_and_sync_resources_to_folio
        # return
        @downloading_errors = []
        @syncing_errors = []
        last_24_hours = Time.now.utc - (ONE_DAY_IN_SECONDS * 28)

        begin
          download_archivesspace_marc_xml(last_24_hours)
        rescue => e
          handle_error('download', e.message)
        end

        begin
          sync_resources_to_folio
        rescue SyncError => e
          handle_error('sync', e.message)
        end
      end

      def download_archivesspace_marc_xml(modified_since)
        begin
          exporter = FolioSync::ArchivesSpace::MarcExporter.new
          exporter.export_recent_resources(modified_since)
        rescue => e
          raise DownloadError, "Failed to download MARC XML: #{e.message}"
        end
      end

      def sync_resources_to_folio
        marc_dir = Rails.root.join('tmp/marc_files')
        folio_writer = FolioSync::Folio::Writer.new

        Dir.foreach(marc_dir) do |file|
          next if ['.', '..'].include?(file)

          begin
            Rails.logger.debug "Processing file: #{file}"
            bibid = File.basename(file, '.xml')

            enhancer = FolioSync::ArchivesSpaceToFolio::MarcRecordEnhancer.new(bibid)
            enhancer.enhance_marc_record!
            marc_record = enhancer.marc_record

            folio_writer.create_or_update_folio_record(marc_record)
          rescue => e
            raise SyncError, "Error processing file #{file}: #{e.message}"
          end
        end
      end

      private

      def handle_error(type, message)
        @logger.error(message)
        @syncing_errors << message if type == 'sync'
        @downloading_errors << message if type == 'download'
      end
    end
  end
end
