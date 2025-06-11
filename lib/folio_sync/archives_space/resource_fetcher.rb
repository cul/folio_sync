# frozen_string_literal: true

require 'fileutils'
require 'pry'

module FolioSync
  module ArchivesSpace
    class ResourceFetcher
      attr_reader :fetching_errors

      PAGE_SIZE = 200

      def initialize(instance_key)
        @logger = Logger.new($stdout) # Ensure logger is initialized first
        @client = FolioSync::ArchivesSpace::Client.new(instance_key)
        @instance_dir = instance_key
        @fetching_errors = []
      end

      # Fetches all resources modified since the given time and saves them to the database.
      def fetch_and_save_recent_resources(modified_since = nil)
        @client.fetch_all_repositories.each do |repo|
          next log_repository_skip(repo) unless repo['publish']

          repo_id = extract_id(repo['uri'])
          fetch_and_save_resources_from_repository(repo_id, modified_since)
        end
      end

      private

      def fetch_and_save_resources_from_repository(repo_id, modified_since)
        query_params = build_query_params(modified_since)

        @client.retrieve_paginated_resources(repo_id, query_params) do |resources|
          resources.each do |resource|
            log_resource_processing(resource)
            save_resource_to_database(repo_id, resource)
          rescue StandardError => e
            @logger.error(
              "Error fetching resource #{resource['id']} (repo_id: #{repo_id}): #{e.message}"
            )
            @fetching_errors << FolioSync::Errors::FetchingError.new(
              resource_uri: resource['uri'],
              message: e.message
            )
          end
        end
      end

      def save_resource_to_database(repo_id, resource)
        json_parsed = resource['json'] ? JSON.parse(resource['json']) : {}
        has_folio_hrid = json_parsed.dig('user_defined', 'boolean_1')
        folio_hrid = nil

        if has_folio_hrid
          folio_hrid = resource['id_0'] if @instance_key == 'cul'
          folio_hrid = resource['user_defined']['string_1'] if @instance_key == 'barnard'
        end

        data_to_save = {
          archivesspace_instance_key: @instance_dir,
          repository_key: repo_id,
          resource_key: extract_id(resource['uri']),
          folio_hrid: folio_hrid,
          pending_update: 'to_folio',
          is_folio_suppressed: !resource['publish']
        }

        AspaceToFolioRecord.create_or_update_from_data(data_to_save)
      end

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
