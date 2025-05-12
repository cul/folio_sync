module FolioSync
  module ArchivesSpace
    class MarcExporter
      ONE_DAY_IN_SECONDS = 24 * 60 * 60
      PAGE_SIZE = 200

      def initialize
        @logger = Logger.new($stdout) # Ensure logger is initialized first
        @client = FolioSync::ArchivesSpace::Client.instance
      end

      def export_recent_resources(modified_since = nil)
        @client.get_all_repositories.each do |repo|
          next log_repository_skip(repo) unless repo['publish']

          repo_id = extract_id(repo['uri'])
          export_resources_from_repository(repo_id, modified_since)
        end
      end

      private

      def export_resources_from_repository(repo_id, modified_since)
        query_params = build_query_params(modified_since)

        @client.retrieve_paginated_resources(repo_id, query_params) do |resources|
          resources.each do |resource|
            log_resource_processing(resource)
            export_marc_for_resource(repo_id, extract_id(resource['uri']), resource['identifier'])
          end
        end
      end

      def export_marc_for_resource(repo_id, resource_id, bib_id)
        marc_data = @client.fetch_marc_xml_resource(repo_id, resource_id)
        return @logger.error("No MARC found for repo #{repo_id} and resource_id #{resource_id}") unless marc_data

        # ! To check: other instances might use the same bib_id
        file_path = Rails.root.join("tmp/marc_files/#{bib_id}.xml")
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
          fields: %w[id identifier system_mtime title publish]
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