# frozen_string_literal: true

module FolioSync
  module ArchivesSpaceToFolio
    class FolioSynchronizer
      VALID_MODES = [:all, :download, :prepare, :sync].freeze

      attr_reader :syncing_errors, :downloading_errors, :saving_errors, :fetching_errors, :linking_errors

      ONE_HOUR_IN_SECONDS = 3600

      def initialize(instance_key)
        @logger = Logger.new($stdout)
        @instance_key = instance_key
        clear_error_arrays!
      end

      # Creates DB records for Aspace records, performs MARC downloads, syncs resources to folio, and updates
      # aspace record metadata after a sync.
      # @param [Integer] last_x_hours Records newer than this are synced.
      # @param [Symbol] mode One of the following values: :all, :download, :sync
      def fetch_and_sync_aspace_to_folio_records(last_x_hours, mode)
        raise ArgumentError, "Invalid mode: #{mode}" unless VALID_MODES.include?(mode)

        if [:all, :download].include?(mode)
          database_valid?
          modified_since = Time.now.utc - (ONE_HOUR_IN_SECONDS * last_x_hours) if last_x_hours

          # 1. Fetch resources from ArchivesSpace based on their modification time and save them to the database
          fetch_archivesspace_resources(modified_since)
          # 2. Download MARC XML files from ArchivesSpace and FOLIO
          download_marc_from_archivesspace_and_folio
        end

        if [:all, :prepare].include?(mode) # rubocop:disable Style/IfUnlessModifier
          prepare_folio_marc_records
        end

        if [:all, :sync].include?(mode) # rubocop:disable Style/GuardClause
          # 3. Enhance MARC records and sync them to FOLIO (including the discoverySuppress status)
          sync_prepared_marc_records_to_folio
          # 4. For newly created FOLIO records, update their respective ASpace records with the FOLIO HRIDs
          update_archivesspace_records
        end
      end

      def fetch_archivesspace_resources(modified_since)
        if modified_since
          @logger.info("Fetching ArchivesSpace resources modified since: #{modified_since.utc} (#{modified_since.to_i})")
        else
          @logger.info('Fetching all ArchivesSpace resources (no time filter)')
        end

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

      # Create a new enhanced MARC binary record and save it to a local directory
      def prepare_folio_marc_records
        @logger.info('Preparing FOLIO MARC records for export')

        pending_records = AspaceToFolioRecord.where(
          archivesspace_instance_key: @instance_key,
          pending_update: 'to_folio'
        )

        pending_records.each do |record|
          aspace_marc_path = record.archivesspace_marc_xml_path
          folio_marc_path = record.folio_marc_xml_path if record.folio_hrid.present?
          prepared_folio_marc_path = record.prepared_folio_marc_path
          @logger.info(
            "Preparing FOLIO MARC record with ASpace MARC path: #{aspace_marc_path}, FOLIO MARC path: #{folio_marc_path}, " \
            "and prepared path: #{prepared_folio_marc_path}"
          )

          enhanced_record = create_enhanced_marc(aspace_marc_path, folio_marc_path, record.folio_hrid)

          # Use MARC::Writer with allow_oversized to handle large MARC records
          writer = MARC::Writer.new(prepared_folio_marc_path)
          writer.allow_oversized = true
          writer.write(enhanced_record)
          writer.close

          @logger.info("Prepared FOLIO MARC record for export: #{prepared_folio_marc_path}")
        rescue StandardError => e
          @logger.error("Failed to prepare FOLIO MARC record for ID #{record.id}: #{e.message}")
          @logger.error("Backtrace: #{e.backtrace.join("\n")}")
          record.update!(pending_update: 'fix_required')
          next
        end
      end

      def create_enhanced_marc(aspace_marc_path, folio_marc_path, folio_hrid)
        enhancer = FolioSync::ArchivesSpaceToFolio::MarcRecordEnhancer.new(aspace_marc_path, folio_marc_path, folio_hrid,
                                                                           @instance_key)
        enhancer.enhance_marc_record!
      end

      def sync_prepared_marc_records_to_folio
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

      def update_archivesspace_records
        pending_records = AspaceToFolioRecord.where(
          archivesspace_instance_key: @instance_key,
          pending_update: 'to_aspace'
        )

        updater = FolioSync::ArchivesSpace::ResourceUpdater.new(@instance_key)
        pending_records.each do |pending_record|
          successful_update = updater.update_single_record(pending_record)
          pending_record.update!(pending_update: 'no_update') if successful_update
        end

        return if updater.updating_errors.blank?

        @logger.error("Errors encountered during ArchivesSpace updates: #{updater.updating_errors}")
        @linking_errors = updater.updating_errors
      end

      # If any of the records in the database has its folio_hrid set to nil,
      # we assume the database is not valid
      def database_valid?
        if AspaceToFolioRecord.exists?(
          archivesspace_instance_key: @instance_key,
          folio_hrid: nil
        )

          ApplicationMailer.with(
            to: Rails.configuration.folio_sync[:aspace_to_folio][:developer_email_address],
            subject: "FOLIO Sync failed to validate database for #{@instance_key}",
            instance_key: @instance_key
          ).folio_sync_database_error_email.deliver

          raise FolioSync::Exceptions::InvalidDatabaseState, "Database is not valid for instance #{@instance_key}."
        end

        @logger.info("Database is valid for instance #{@instance_key}.")
        true
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
        @linking_errors = []
      end
    end
  end
end
