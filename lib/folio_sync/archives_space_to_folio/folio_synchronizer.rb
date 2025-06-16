# frozen_string_literal: true

module FolioSync
  module ArchivesSpaceToFolio
    class FolioSynchronizer
      attr_reader :syncing_errors, :downloading_errors

      ONE_HOUR_IN_SECONDS = 3600

      def initialize(instance_key)
        @logger = Logger.new($stdout)
        @instance_key = instance_key

        @fetching_errors = []
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

      # WIP - new sync method
      def fetch_and_sync_aspace_to_folio_records(last_x_hours)
        @fetching_errors = []
        @downloading_errors = []
        @syncing_errors = []
        modified_since = Time.now.utc - (ONE_HOUR_IN_SECONDS * last_x_hours) if last_x_hours

        # fetch_archivesspace_resources(modified_since)
        # download_marc_from_archivesspace_and_folio
        refactored_sync_resources_to_folio
      end

      def fetch_archivesspace_resources(modified_since)
        @logger.info("Fetching ArchivesSpace resources modified since: #{modified_since}")

        fetcher = FolioSync::ArchivesSpace::ResourceFetcher.new(@instance_key)
        fetcher.fetch_and_save_recent_resources(modified_since)

        return if fetcher.fetching_errors.blank?

        @logger.error("Error fetching resources from ArchivesSpace: #{fetcher.fetching_errors}")
        @fetching_errors = fetcher.fetching_errors
      end

      # New download method
      def download_marc_from_archivesspace_and_folio
        downloader = FolioSync::ArchivesSpaceToFolio::MarcDownloader.new(@instance_key)
        downloader.download_pending_marc_records

        return if downloader.downloading_errors.blank?

        @logger.error("Errors encountered during MARC download: #{downloader.downloading_errors}")
        @downloading_errors = downloader.downloading_errors
      end

      def download_archivesspace_marc_xml(modified_since)
        exporter = FolioSync::ArchivesSpace::MarcExporter.new(@instance_key)
        exporter.export_recent_resources(modified_since)

        return if exporter.exporting_errors.blank?

        @logger.error("Errors encountered during MARC XML download: #{exporter.exporting_errors}")
        @downloading_errors = exporter.exporting_errors
      end

      def refactored_sync_resources_to_folio
        pending_records = AspaceToFolioRecord.where(
          archivesspace_instance_key: @instance_key,
          pending_update: 'to_folio'
        )

        pending_records.each do |record|
          config = Rails.configuration.folio_sync[:aspace_to_folio]

          aspace_marc_path = File.join(config[:marc_download_base_directory], record.archivesspace_marc_xml_path)
          # puts aspace_marc_path
          folio_marc_path = nil
          if record.folio_hrid.present?
            folio_marc_path = File.join(config[:marc_download_base_directory], record.folio_marc_xml_path)
          end
          enhancer = FolioSync::ArchivesSpaceToFolio::MarcRecordEnhancer.new(
            aspace_marc_path,
            folio_marc_path,
            record.folio_hrid,
            @instance_key
          )
          enhancer.enhance_marc_record!
          enhanced_record = enhancer.marc_record
        end

        # pending_records.each do |record|
        #   config = Rails.configuration.folio_sync[:aspace_to_folio]

        #   aspace_marc_path = File.join(config[:marc_download_base_directory], record.archivesspace_marc_xml_path)
        #   # puts aspace_marc_path
        #   folio_marc_path = nil
        #   if record.folio_hrid.present?
        #     folio_marc_path = File.join(config[:marc_download_base_directory], record.folio_marc_xml_path)
        #   end
        #   puts "About to enhance record with id #{record.resource_key}"
        #   puts "Folio path is #{folio_marc_path}" if folio_marc_path
        #   enhanced_record = FolioSync::ArchivesSpaceToFolio::MarcRecordEnhancer.new(
        #     aspace_marc_path,
        #     folio_marc_path,
        #     record.folio_hrid,
        #     @instance_key
        #   )
        #   enhanced_record.test
        # rescue StandardError => e
        #   @downloading_errors << FolioSync::Errors::DownloadingError.new(
        #     resource_uri: "repositories/#{record.repository_key}/resources/#{record.resource_key}",
        #     message: e.message
        #   )
        # end
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

      def clear_downloads!
        config = Rails.configuration.folio_sync[:aspace_to_folio]
        downloads_dir = File.join(config[:marc_download_base_directory], @instance_key)
        FileUtils.rm_rf(Dir["#{downloads_dir}/*"])
      end
    end
  end
end
