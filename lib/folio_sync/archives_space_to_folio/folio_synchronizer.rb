# frozen_string_literal: true

module FolioSync
  module ArchivesSpaceToFolio
    class FolioSynchronizer
      def initialize
        @logger = Logger.new($stdout)
      end

      def fetch_and_sync_resources_to_folio
        download_archivesspace_marc_xml
        sync_resources_to_folio
      end

      def download_archivesspace_marc_xml
        exporter = FolioSync::ArchivesSpace::MarcExporter.new
        exporter.export_recent_resources
      end

      def sync_resources_to_folio
        # Iterate over all files in the tmp/marc_files directory
        # Use foreach for better performance with large directories
        marc_dir = Rails.root.join('tmp/marc_files')
        folio_writer = FolioSync::Folio::Writer.new

        Dir.foreach(marc_dir) do |file|
          next if ['.', '..'].include?(file)

          Rails.logger.debug "Processing file: #{file}"
          bibid = File.basename(file, '.xml')

          enhancer = FolioSync::ArchivesSpaceToFolio::MarcRecordEnhancer.new(bibid)
          enhancer.enhance_marc_record!
          marc_record = enhancer.marc_record

          folio_writer.create_or_update_folio_record(marc_record)
        end
      end
    end
  end
end
