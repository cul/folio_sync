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
        @csv_file_path = Rails.root.join(
          "tmp/#{instance_key}_updated_aspace_resources_#{Time.zone.now.strftime('%Y%m%d%H%M%S')}.csv"
        )
      end

      def retrieve_and_sync_aspace_resources
        CSV.open(@csv_file_path, 'w') do |csv|
          csv << ['Resource URI', 'HRID']

          @aspace_client.fetch_all_repositories.each do |repo|
            next log_repository_skip(repo) unless repo['publish']

            repo_id = extract_id(repo['uri'])
            fetch_from_repo_and_update_resources(repo_id, csv)
          end
        end
      end

      def determine_potential_hrid(resource)
        if @instance_key == 'cul'
          resource['id_0']
        elsif @instance_key == 'barnard'
          resource.dig('user_defined', 'string_1')
        end
      end

      def fetch_from_repo_and_update_resources(repo_id, csv)
        query_params = build_query_params

        @aspace_client.retrieve_resources_for_repository(repo_id, query_params) do |resources|
          resources.each do |resource|
            next unless should_process_resource?(resource)

            potential_hrid = determine_potential_hrid(resource)
            next unless potential_hrid

            source_record = @folio_client.find_source_record(instance_record_hrid: potential_hrid)

            if source_record
              update_aspace_record(resource, repo_id)
              write_to_csv(resource, potential_hrid, csv)
            end
          rescue StandardError => e
            @logger.error("Error updating resource #{resource['uri']}: #{e.message}")
          end
        end
      end

      def write_to_csv(resource, potential_hrid, csv)
        csv << [resource['uri'], potential_hrid]
      end

      def update_aspace_record(resource, repo_id)
        resource['user_defined'] ||= {}
        resource['user_defined']['boolean_1'] = true

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

      def should_process_resource?(resource)
        return false if resource['suppressed']
        return false if resource.dig('user_defined', 'boolean_1') # Already processed

        case @instance_key
        when 'cul'
          resource['id_0'].present?
        when 'barnard'
          resource.dig('user_defined', 'string_1').present?
        else
          false
        end
      end
    end
  end
end
