require 'fileutils'

module FolioSync
  module ArchivesSpaceToFolio
    class MarcDownloader
      attr_reader :downloading_errors

      def initialize(instance_key)
        @logger = Logger.new($stdout) # Ensure logger is initialized first
        @instance_key = instance_key
        @aspace_client = FolioSync::ArchivesSpace::Client.new(instance_key)
        @folio_client = FolioSync::Folio::Client.instance
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
          @downloading_errors << "Error downloading MARC record for #{record.archivesspace_instance_key}: #{e.message}"
          Rails.logger.error(@downloading_errors.last)
        end
      end

      def download_marc_for_record(record)
        aspace_marc = @aspace_client.fetch_marc_xml_resource(record.repository_key, record.resource_key)
        puts "Downloaded aspace marc: #{aspace_marc}"
        save_marc(aspace_marc, 'aspace')

        return
        return if record.folio_hrid.blank?

        folio_marc = get_marc_record(record.folio)
        save_marc(folio_marc, 'folio')
      end

      def save_marc(marc, from_api)
        # Save ArchivesSpace MARC as
        # instance_key + '/' + repository_id + '-' + resource_id + '-aspace.xml'
        #
        # Save FOLIO MARC as
        # instance_key + '/' + repository_id + '-' + resource_id + '-folio.xml'
      end
    end
  end
end
