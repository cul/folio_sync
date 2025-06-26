# frozen_string_literal: true

# Updates ArchivesSpace resources with FOLIO HRIDs
module FolioSync
  module ArchivesSpace
    class ResourceUpdater
      attr_reader :updating_errors

      def initialize(instance_key)
        @logger = Logger.new($stdout)
        @client = FolioSync::ArchivesSpace::Client.new(instance_key)
        @instance_key = instance_key
        @updating_errors = []
      end

      def update_records(records)
        records.each do |record|
          update_single_record(record)
        end
      end

      def update_single_record(record)
        update_archivesspace_resource(record)
        mark_record_as_updated(record)
        @logger.info("Successfully updated ArchivesSpace record #{record.id}")
      rescue StandardError => e
        @logger.error("Error updating ArchivesSpace record #{record.id}: #{e.message}")
        @updating_errors << FolioSync::Errors::SyncingError.new(
          resource_uri: "repositories/#{record.repository_key}/resources/#{record.resource_key}",
          message: e.message
        )
      end

      def update_archivesspace_resource(record)
        case @instance_key
        when 'cul'
          update_id_fields(record)
        when 'barnard'
          update_string_1_field(record)
        else
          raise ArgumentError, "Unknown instance key: #{@instance_key}"
        end
      end

      def update_resource_with_folio_data(repo_id, resource_id)
        resource_data = @client.fetch_resource(repo_id, resource_id)

        # Instance-specific updates
        updated_resource_data = yield(resource_data)

        # Always update boolean_1 to indicate a successful FOLIO sync
        user_defined = updated_resource_data['user_defined'] || {}
        user_defined['boolean_1'] = true

        final_resource_data = updated_resource_data.merge('user_defined' => user_defined)
        @client.update_resource(repo_id, resource_id, final_resource_data)
      end

      def update_id_fields(record)
        update_resource_with_folio_data(record.repository_key, record.resource_key) do |resource_data|
          resource_data.merge(
            'id_0' => record.folio_hrid,
            'ead_id' => record.folio_hrid
          )
        end
      end

      def update_string_1_field(record)
        update_resource_with_folio_data(record.repository_key, record.resource_key) do |resource_data|
          user_defined = resource_data['user_defined'] || {}
          user_defined['string_1'] = record.folio_hrid
          resource_data.merge('user_defined' => user_defined)
        end
      end

      def mark_record_as_updated(record)
        record.update!(pending_update: 'no_update')
      end
    end
  end
end
