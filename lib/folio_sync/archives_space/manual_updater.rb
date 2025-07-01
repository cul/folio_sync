# frozen_string_literal: true

require 'csv'

# This class is meant to be used in a one-time manual step
module FolioSync
  module ArchivesSpace
    class ManualUpdater
      PAGE_SIZE = 200

      def initialize(instance_key)
        @logger = Logger.new($stdout)
        @aspace_client = FolioSync::ArchivesSpace::Client.new(instance_key)
        @folio_client = FolioSync::Folio::Client.instance
        @instance_key = instance_key
      end

      def retrieve_and_sync_aspace_resources
        @aspace_client.fetch_all_repositories.each do |repo|
          next log_repository_skip(repo) unless repo['publish']

          repo_id = extract_id(repo['uri'])
          fetch_from_repo_and_update_resources(repo_id)
        end
      end

      def fetch_from_repo_and_update_resources(repo_id)
        query_params = build_query_params

        @aspace_client.retrieve_resources_for_repository(repo_id, query_params) do |resources|
          resources.each do |resource|
            next if resource['suppressed']

            potential_hrid = resource['id_0'] if @instance_key == 'cul'
            source_record = @folio_client.find_source_record(instance_record_hrid: potential_hrid)

            if source_record
              log_resource_processing(resource)
              update_aspace_record(resource, repo_id)
            end
          rescue StandardError => e
            @logger.error("Error updating resource #{resource['uri']}: #{e.message}")
          end
        end
      end

      def update_aspace_record(resource, repo_id)
        user_defined = resource['user_defined'] || {}
        user_defined['boolean_1'] = true

        @aspace_client.update_resource(repo_id, extract_id(resource['uri']), resource)
      end

      def build_query_params
        { page: 1, page_size: PAGE_SIZE }
      end

      def extract_id(uri)
        uri.split('/').last
      end

      def log_repository_skip(repo)
        @logger.info("Repository #{repo['uri']} is not published, skipping...")
      end

      def log_resource_processing(resource)
        @logger.info("Processing resource: #{resource['title']} (URI: #{resource['uri']})")
      end
    end
  end
end
