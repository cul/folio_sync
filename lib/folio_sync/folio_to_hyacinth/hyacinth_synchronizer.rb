# frozen_string_literal: true

module FolioSync
  module FolioToHyacinth
    class HyacinthSynchronizer
      attr_reader :downloading_errors, :syncing_errors

      def initialize
        @logger = Logger.new($stdout)
      end

      # Performs MARC downloads and syncs resources to Hyacinth
      # @param [Integer] last_x_hours Records newer than this are synced.
      def download_and_sync_folio_to_hyacinth_records(last_x_hours)
        # download_marc_from_folio(last_x_hours)
        prepare_hyacinth_records
      end

      def clear_downloads!
        @logger.info('Clearing downloaded MARC files...')
        FileUtils.rm_rf(downloaded_marc_files_path)
      end

      def download_marc_from_folio(last_x_hours)
        downloader = FolioSync::FolioToHyacinth::MarcDownloader.new
        downloader.download_965hyacinth_marc_records(last_x_hours)

        return if downloader.downloading_errors.blank?

        @logger.error("Error downloading MARC records from FOLIO: #{downloader.downloading_errors}")
        @downloading_errors = downloader.downloading_errors
      end

      def prepare_hyacinth_records
        marc_files = Dir.glob(downloaded_marc_files_path)
        puts "Processing #{marc_files.count} MARC files"

        marc_files.each do |marc_file_path|
          process_marc_file(marc_file_path)
        end
      end

      private

      def downloaded_marc_files_path
        "#{Rails.configuration.folio_to_hyacinth[:download_directory]}/*.mrc"
      end

      def process_marc_file(marc_file_path)
        processor = FolioSync::FolioToHyacinth::MarcProcessor.new(marc_file_path)
        processor.create_and_sync_hyacinth_record!
      end
    end
  end
end
