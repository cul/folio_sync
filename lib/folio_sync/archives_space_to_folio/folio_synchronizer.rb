# frozen_string_literal: true

module FolioSync
  module ArchivesSpaceToFolio
    class FolioSynchronizer
      attr_reader :syncing_errors, :downloading_errors, :saving_errors, :fetching_errors

      ONE_HOUR_IN_SECONDS = 3600

      def initialize(instance_key)
        @logger = Logger.new($stdout)
        @instance_key = instance_key

        @saving_errors = []
        @fetching_errors = []
        @downloading_errors = []
        @syncing_errors = []
      end

      def fetch_and_sync_aspace_to_folio_records(last_x_hours)
        @fetching_errors = []
        @saving_errors = []
        @downloading_errors = []
        @syncing_errors = []
        modified_since = Time.now.utc - (ONE_HOUR_IN_SECONDS * last_x_hours) if last_x_hours

        fetch_archivesspace_resources(modified_since)
        download_marc_from_archivesspace_and_folio
        sync_resources_to_folio
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

        # Collect errors from batch processor
        @syncing_errors.concat(batch_processor.batch_errors)
        @syncing_errors.concat(batch_processor.processing_errors)

        return unless @syncing_errors.any?

        @logger.error("Errors encountered during sync: #{@syncing_errors.length} total errors")
      end

      def clear_downloads!
        config = Rails.configuration.folio_sync[:aspace_to_folio]
        downloads_dir = File.join(config[:marc_download_base_directory], @instance_key)
        FileUtils.rm_rf(Dir["#{downloads_dir}/*"])
      end
    end
  end
end
