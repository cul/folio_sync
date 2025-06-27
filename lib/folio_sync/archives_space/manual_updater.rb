# frozen_string_literal: true

require 'csv'

# This class is meant to be used in a one-time manual step
module FolioSync
  module ArchivesSpace
    class ManualUpdater
      PAGE_SIZE = 2 # Reduced for testing purposes

      def initialize(instance_key)
        @logger = Logger.new($stdout)
        @aspace_client = FolioSync::ArchivesSpace::Client.new(instance_key)
        @folio_client = FolioSync::Folio::Client.instance
        @instance_key = instance_key

        initialize_csv_file
      end

      def retrieve_sync_aspace_resources
        @aspace_client.fetch_all_repositories.each do |repo|
          next log_repository_skip(repo) unless repo['publish']

          repo_id = extract_id(repo['uri'])
          fetch_from_repository(repo_id)
        end
      end

      def fetch_from_repository(repo_id)
        query_params = build_query_params

        @aspace_client.retrieve_resources_for_repository(repo_id, query_params) do |resources|
          resources.each do |resource|
            next if resource['suppressed']

            retrieve_folio_record(resource)
          rescue StandardError => e
            @logger.error("Error fetching resource #{resource['uri']}: #{e.message}")
          end
        end
      end

      def retrieve_folio_record(resource)
        potential_hrid = resource['id_0'] if @instance_key == 'cul'

        # Check if a record of this resource already exists in FOLIO
        source_record = @folio_client.find_source_record(instance_record_hrid: potential_hrid)
        return unless source_record

        puts "Found source record for hrid: #{potential_hrid}"
        append_to_csv(potential_hrid, resource['uri'], source_record['recordId'])
      end

      # Initializes the CSV file with headers if it doesn't exist
      def initialize_csv_file
        file_path = 'aspace_analysis.csv'

        return if File.exist?(file_path)

        CSV.open(file_path, 'w') do |csv|
          csv << ['hrid', 'aspace_uri', 'folio_record_id']
        end
      end

      # Appends to a CSV file for the processed resources
      def append_to_csv(hrid, aspace_uri, folio_record_id)
        file_path = 'aspace_analysis.csv'

        CSV.open(file_path, 'a') do |csv|
          csv << [hrid, aspace_uri, folio_record_id]
        end
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
        @logger.info("Processing resource: #{resource['title']} (ID: #{resource['id']})")
      end
    end
  end
end
