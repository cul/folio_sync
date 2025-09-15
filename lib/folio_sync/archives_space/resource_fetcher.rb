# frozen_string_literal: true

require 'fileutils'

module FolioSync
  module ArchivesSpace
    class ResourceFetcher
      attr_reader :fetching_errors, :saving_errors

      PAGE_SIZE = 200

      def initialize(instance_key)
        @logger = Logger.new($stdout) # Ensure logger is initialized first
        @client = FolioSync::ArchivesSpace::Client.new(instance_key)
        @instance_key = instance_key
        @fetching_errors = []
        @saving_errors = []
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

        @client.retrieve_resources_for_repository(repo_id, query_params) do |resources|
          resources.each do |resource|
            next if resource['suppressed']

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
        has_folio_hrid = resource.dig('user_defined', 'boolean_1')
        folio_hrid = nil

        if has_folio_hrid
          folio_hrid = resource['id_0'] if @instance_key == 'cul'
          folio_hrid = resource.dig('user_defined', 'string_1') if @instance_key == 'barnard'
        end

        holdings_call_number = resolve_call_number(resource, repo_id)
        data_to_save = {
          archivesspace_instance_key: @instance_key,
          repository_key: repo_id,
          resource_key: extract_id(resource['uri']),
          folio_hrid: folio_hrid,
          pending_update: 'to_folio',
          is_folio_suppressed: !resource['publish'],
          holdings_call_number: holdings_call_number
        }

        AspaceToFolioRecord.create_or_update_from_data(data_to_save)
      rescue StandardError => e
        @logger.error("Error saving resource #{resource['id']} to database: #{e.message}")
        @saving_errors << FolioSync::Errors::SavingError.new(
          resource_uri: resource['uri'],
          message: e.message
        )
      end

      # Builds query parameters for fetching resources.
      # If a modification time is provided, the query filters resources updated since that time.
      # The modified_since parameter should be a Time object, which gets converted to a Unix timestamp.
      # Otherwise, it retrieves all unsuppressed resources.
      # Note: Other instances may have different requirements for the query.
      def build_query_params(modified_since = nil)
        query = {
          page: 1,
          page_size: PAGE_SIZE
        }

        if modified_since
          # Convert Time object to Unix timestamp
          query[:modified_since] = modified_since.to_i
        end

        query
      end

      def resolve_call_number(resource, repo_id)
        return [resource['id_0'], resource['id_1']].compact.join('.') if @instance_key == 'barnard'

        repo_id == '2' ? resource.dig('user_defined', 'string_1') : resource['title']
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
