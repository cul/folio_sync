# frozen_string_literal: true

module FolioSync
  module FolioToHyacinth
    class HyacinthSynchronizer
      attr_reader :downloading_errors, :syncing_errors

      def initialize
        # @logger = Logger.new($stdout)
      end

      # Performs MARC downloads and syncs resources to Hyacinth
      # @param [Integer] last_x_hours Records newer than this are synced.
      def download_and_sync_folio_to_hyacinth_records(last_x_hours)
        download_marc_from_folio(last_x_hours)
        prepare_hyacinth_records
      end

      def download_marc_from_folio(last_x_hours)
        downloader = FolioSync::FolioToHyacinth::MarcDownloader.new
        downloader.download_965hyacinth_marc_records(last_x_hours)

        return if downloader.downloading_errors.blank?

        puts "Error downloading MARC records from FOLIO: #{downloader.downloading_errors}"
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
        folio_hrid = extract_hrid_from_filename(marc_file_path)
        hyacinth_results = fetch_hyacinth_results(marc_file_path)
        puts "Found #{hyacinth_results.length} Hyacinth records for FOLIO HRID #{folio_hrid}"

        case hyacinth_results.length
        when 0
          create_new_hyacinth_record(marc_file_path, folio_hrid)
        when 1
          update_existing_hyacinth_record(marc_file_path, hyacinth_results.first, folio_hrid)
        else
          handle_multiple_records_error(folio_hrid)
        end
      rescue StandardError => e
        puts "Failed to process #{folio_hrid}: #{e.message}"
        @syncing_errors << "Error processing #{folio_hrid}: #{e.message}"
      end

      def extract_hrid_from_filename(marc_file_path)
        File.basename(marc_file_path, '.mrc')
      end

      def create_new_hyacinth_record(marc_file_path, folio_hrid)
        puts "Creating new Hyacinth record for #{folio_hrid}"

        new_record = FolioToHyacinthRecord.new(marc_file_path)
        response = FolioSync::Hyacinth::Client.instance.create_new_record(
          new_record.digital_object_data,
          publish: true
        )

        puts "Created record for #{folio_hrid}: #{response.inspect}"
        response
      end

      def update_existing_hyacinth_record(marc_file_path, existing_record, folio_hrid)
        puts "Updating existing Hyacinth record for #{folio_hrid}"

        preserved_data = { 'identifiers' => existing_record['identifiers'] }
        updated_record = FolioToHyacinthRecord.new(marc_file_path, preserved_data)

        response = FolioSync::Hyacinth::Client.instance.update_existing_record(
          existing_record['pid'],
          updated_record.digital_object_data,
          publish: true
        )

        puts "Updated record #{existing_record['pid']}: #{response.inspect}"
        response
      end

      def handle_multiple_records_error(folio_hrid)
        error_message = "Multiple Hyacinth records found for FOLIO HRID #{folio_hrid}"
        puts error_message
        @syncing_errors << error_message
      end

      def fetch_hyacinth_results(marc_file_path)
        folio_hrid = File.basename(marc_file_path, '.mrc')
        potential_clio_identifier = "clio#{folio_hrid}"
        client = FolioSync::Hyacinth::Client.instance
        client.find_by_identifier(potential_clio_identifier,
                                  { f: { digital_object_type_display_label_sim: ['Item'] } })
      end
    end
  end
end
