# frozen_string_literal: true

require 'fileutils'
require 'pry'

module FolioSync
  module ArchivesSpace
    class MarcExporter
      attr_reader :exporting_errors

      PAGE_SIZE = 200

      def initialize(instance_key)
        @logger = Logger.new($stdout) # Ensure logger is initialized first
        @client = FolioSync::ArchivesSpace::Client.new(instance_key)
        @instance_dir = instance_key
        @exporting_errors = []
      end

      def export_recent_resources(modified_since = nil)
        @client.fetch_all_repositories.each do |repo|
          next log_repository_skip(repo) unless repo['publish']

          repo_id = extract_id(repo['uri'])
          export_resources_from_repository(repo_id, modified_since)
        end
      end

      def fetch_recent_resources(modified_since = nil)
        @client.fetch_all_repositories.each do |repo|
          next log_repository_skip(repo) unless repo['publish']

          repo_id = extract_id(repo['uri'])
          fetch_resources_from_repository(repo_id, modified_since)
        end
      end

      def fetch_resources_from_repository(repo_id, modified_since)
        query_params = build_query_params(modified_since)

        @client.retrieve_paginated_resources(repo_id, query_params) do |resources|
          resources.each do |resource|
            log_resource_processing(resource)

            # If boolean_1 is true, the resource has been previously synced to FOLIO
            # and we want to save its HRID in the database.
            folio_hrid = nil
            json_parsed = resource['json'] ? JSON.parse(resource['json']) : {}
            has_folio_hrid = json_parsed.dig('user_defined', 'boolean_1')

            if has_folio_hrid
              folio_hrid = resource['id_0'] if @instance_key == 'cul'
              folio_hrid = resource['user_defined']['string_1'] if @instance_key == 'barnard'
            end

            create_or_update_entry_for_resource(repo_id, extract_id(resource['uri']), resource['publish'], folio_hrid)
          end
        end
      end

      def create_or_update_entry_for_resource(repo_id, resource_id, published, hrid = nil)
        data_to_save = {
          archivesspace_instance_key: @instance_dir,
          repository_key: repo_id,
          resource_key: resource_id,
          folio_hrid: hrid,
          pending_update: 'to_folio',
          is_folio_suppressed: !published
        }
        puts "Creating entry for resource: #{data_to_save.inspect}"
      end

      private

      def export_resources_from_repository(repo_id, modified_since)
        query_params = build_query_params(modified_since)

        @client.retrieve_paginated_resources(repo_id, query_params) do |resources|
          resources.each do |resource|
            log_resource_processing(resource)
            export_marc_for_resource(repo_id, extract_id(resource['uri']), resource['identifier'])
          rescue StandardError => e
            @logger.error(
              "Error exporting MARC for resource #{resource['identifier']} " \
              "(repo_id: #{repo_id}): #{e.message}"
            )
            @exporting_errors << FolioSync::Errors::DownloadingError.new(
              resource_uri: resource['uri'],
              message: e.message
            )
          end
        end
      end

      def export_marc_for_resource(repo_id, resource_id, bib_id)
        raise 'No bib_id found' if bib_id.nil?

        marc_data = @client.fetch_marc_xml_resource(repo_id, resource_id)
        return @logger.error("No MARC found for repo #{repo_id} and resource_id #{resource_id}") unless marc_data

        config = Rails.configuration.folio_sync[:aspace_to_folio]
        file_path = File.join(config[:marc_download_base_directory], @instance_dir, "#{bib_id}.xml")

        File.binwrite(file_path, marc_data)
      end

      # Builds query parameters for fetching resources.
      # If a modification time is provided, the query filters resources updated since that time.
      # Otherwise, it retrieves all unsuppressed resources.
      # Note: Other instances may have different requirements for the query.
      def build_query_params(modified_since = nil)
        query = {
          q: 'primary_type:resource suppressed:false',
          page: 1,
          page_size: PAGE_SIZE,
          fields: %w[id identifier system_mtime title publish json]
        }

        query[:q] += " system_mtime:[#{time_to_solr_date_format(modified_since)} TO *]" if modified_since

        query
      end

      def time_to_solr_date_format(time)
        time.utc.strftime('%Y-%m-%dT%H:%M:%S.%LZ')
      end

      def extract_id(uri)
        uri.split('/').last
      end

      def log_repository_skip(repo)
        @logger.info("Repository #{repo['uri']} is not published, skipping...")
      end

      def log_resource_processing(resource)
        @logger.info("Processing resource: #{resource['title']} (ID: #{resource['id']})")
      end
    end
  end
end
