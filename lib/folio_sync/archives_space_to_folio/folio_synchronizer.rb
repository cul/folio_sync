# frozen_string_literal: true

module FolioSync
  module ArchivesSpaceToFolio
    class FolioSynchronizer
      attr_reader :syncing_errors, :downloading_errors, :saving_errors, :fetching_errors, :linking_errors

      ONE_HOUR_IN_SECONDS = 3600

      def initialize(instance_key)
        @logger = Logger.new($stdout)
        @instance_key = instance_key

        @saving_errors = []
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
        @saving_errors = []
        @downloading_errors = []
        @syncing_errors = []
        modified_since = Time.now.utc - (ONE_HOUR_IN_SECONDS * last_x_hours) if last_x_hours

        fetch_archivesspace_resources(modified_since)
        download_marc_from_archivesspace_and_folio
        sync_resources_to_folio
        update_archivesspace_records
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

      def sync_resources_to_folio
        pending_records = AspaceToFolioRecord.where(
          archivesspace_instance_key: @instance_key,
          pending_update: 'to_folio'
        )

        pending_records.each do |record|
          config = Rails.configuration.folio_sync[:aspace_to_folio]

          aspace_marc_path = File.join(config[:marc_download_base_directory], record.archivesspace_marc_xml_path)
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
          enhancer.marc_record
          # TODO: Sync to FOLIO
          # enhanced_record = enhancer.marc_record
        rescue StandardError => e
          @logger.error("Error syncing resources to FOLIO: #{e.message}")
          @syncing_errors << FolioSync::Errors::SyncingError.new(
            resource_uri: "repositories/#{record.repository_key}/resources/#{record.resource_key}",
            message: e.message
          )
        end
      end

      def update_archivesspace_records
        pending_records = AspaceToFolioRecord.where(
          archivesspace_instance_key: @instance_key,
          pending_update: 'to_aspace'
        )

        updater = FolioSync::ArchivesSpace::ResourceUpdater.new(@instance_key)
        updater.update_records(pending_records)

        return if updater.updating_errors.blank?

        @logger.error("Errors encountered during ArchivesSpace updates: #{updater.updating_errors}")
        @linking_errors = updater.updating_errors
      end

      def clear_downloads!
        config = Rails.configuration.folio_sync[:aspace_to_folio]
        downloads_dir = File.join(config[:marc_download_base_directory], @instance_key)
        FileUtils.rm_rf(Dir["#{downloads_dir}/*"])
      end
    end
  end
end
