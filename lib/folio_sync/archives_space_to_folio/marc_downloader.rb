# frozen_string_literal: true

require 'fileutils'

module FolioSync
  module ArchivesSpaceToFolio
    class MarcDownloader
      attr_reader :downloading_errors

      def initialize(instance_key)
        @logger = Logger.new($stdout) # Ensure logger is initialized first
        @instance_key = instance_key
        @aspace_client = FolioSync::ArchivesSpace::Client.new(instance_key)
        @folio_reader = FolioSync::Folio::Reader.new
        @downloading_errors = []
      end

      def download_pending_marc_records
        pending_records = AspaceToFolioRecord.where(
          archivesspace_instance_key: @instance_key,
          pending_update: 'to_folio'
        )

        pending_records.each do |record|
          download_marc_for_record(record)
        rescue StandardError => e
          @downloading_errors << FolioSync::Errors::DownloadingError.new(
            resource_uri: "repositories/#{record.repository_key}/resources/#{record.resource_key}",
            message: e.message
          )
        end
      end

      def download_marc_for_record(record)
        aspace_marc = @aspace_client.fetch_marc_xml_resource(record.repository_key, record.resource_key)
        save_marc_file(record.archivesspace_marc_xml_path, aspace_marc)

        return if record.folio_hrid.blank?

        folio_marc = @folio_reader.get_marc_record_as_xml(record.folio_hrid)
        save_marc_file(record.folio_marc_xml_path, folio_marc) if folio_marc
      end

      def save_marc_file(file_path, marc_data)
        File.binwrite(file_path, marc_data)
      end
    end
  end
end
