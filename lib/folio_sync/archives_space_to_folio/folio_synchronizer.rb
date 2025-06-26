# frozen_string_literal: true

module FolioSync
  module ArchivesSpaceToFolio
    class FolioSynchronizer
      attr_reader :syncing_errors, :downloading_errors, :saving_errors, :fetching_errors

      ONE_HOUR_IN_SECONDS = 3600

      def initialize(instance_key)
        @logger = Logger.new($stdout)
        @instance_key = instance_key
        clear_error_arrays!
      end

      def fetch_and_sync_aspace_to_folio_records(last_x_hours)
        clear_error_arrays!
        modified_since = Time.now.utc - (ONE_HOUR_IN_SECONDS * last_x_hours) if last_x_hours

        # 1. Fetch resources from ArchivesSpace based on their modification time and save them to the database
        fetch_archivesspace_resources(modified_since)
        # 2. Download MARC XML files from ArchivesSpace and FOLIO
        download_marc_from_archivesspace_and_folio
        # 3. Enhance MARC records and sync them to FOLIO (including the discoverySuppress status)
        sync_resources_to_folio
        # 4. TODO: For newly created FOLIO records, update their respective ASpace records with the FOLIO HRIDs
      end

      def fetch_archivesspace_resources(modified_since)
        @logger.info("Fetching ArchivesSpace resources modified since: #{modified_since}")

        fetcher = FolioSync::ArchivesSpace::ResourceFetcher.new(@instance_key)
        fetcher.fetch_and_save_recent_resources(modified_since)

        if fetcher.fetching_errors.present?
          @logger.error("Error fetching resources from ArchivesSpace: #{fetcher.fetching_errors}")
          @fetching_errors = fetcher.fetching_errors
        end

        return if fetcher.saving_errors.blank?

        @logger.error("Error saving resources to database: #{fetcher.saving_errors}")
        @saving_errors = fetcher.saving_errors
      end

      def download_marc_from_archivesspace_and_folio
        downloader = FolioSync::ArchivesSpaceToFolio::MarcDownloader.new(@instance_key)
        downloader.download_pending_marc_records

        return if downloader.downloading_errors.blank?

        @logger.error("Errors encountered during MARC download: #{downloader.downloading_errors}")
        @downloading_errors = downloader.downloading_errors
      end

      def sync_resources_to_folio
        pending_records = AspaceToFolioRecord.where(
          archivesspace_instance_key: @instance_key,
          pending_update: 'to_folio'
        )

        if pending_records.empty?
          @logger.info("No pending records to sync for instance: #{@instance_key}")
          return
        end

        @logger.info("Found #{pending_records.count} pending records to sync")

        batch_processor = BatchProcessor.new(@instance_key)
        batch_processor.process_records(pending_records)

        return if batch_processor.syncing_errors.blank?

        @logger.error("Errors encountered during sync: #{batch_processor.syncing_errors}")
        @syncing_errors = batch_processor.syncing_errors
      end

      def clear_downloads!
        config = Rails.configuration.folio_sync[:aspace_to_folio]
        downloads_dir = File.join(config[:marc_download_base_directory], @instance_key)
        FileUtils.rm_rf(Dir["#{downloads_dir}/*"])
      end

      private

      def clear_error_arrays!
        @syncing_errors = []
        @downloading_errors = []
        @saving_errors = []
        @fetching_errors = []
      end
    end
  end
end
