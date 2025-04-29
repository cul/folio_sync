# frozen_string_literal: true

module FolioSync
  class FolioSynchronizer
    ONE_DAY_IN_SECONDS = 24 * 60 * 60
    PAGE_SIZE = 200

    def initialize
      @logger = Logger.new($stdout) # Ensure logger is initialized first
      @aspace_client = FolioSync::ArchivesSpace::Client.instance
    end

    # Main method, will be replaced with something like sync_resources_to_folio
    def fetch_recent_marc_resources
      @aspace_client.get_all_repositories.each do |repo|
        next log_repository_skip(repo) unless repo['publish']

        repo_id = extract_id(repo['uri'])
        fetch_resources_for_repo(repo_id)
      end
    end

    private

    def fetch_resources_for_repo(repo_id)
      last_24h = Time.now.utc - ONE_DAY_IN_SECONDS
      query_params = build_query_params(last_24h)

      @aspace_client.retrieve_paginated_resources(repo_id, query_params) do |resources|
        resources.each do |resource|
          log_resource_processing(resource)
          fetch_and_save_marc(repo_id, extract_id(resource['uri']))
        end
      end
    end

    def fetch_and_save_marc(repo_id, resource_id)
      marc_data = @aspace_client.fetch_marc_data(repo_id, resource_id)

      # For now we're saving the MARC data locally
      save_marc_locally(marc_data) if marc_data
    end

    # Builds query parameters for fetching resources updated within the last 24 hours.
    # The query includes unpublished resources and filters by system_mtime.
    # Note: Other instances may have different requirements for the query.
    def build_query_params(last_24h)
      {
        q: "primary_type:resource suppressed:false system_mtime:[#{time_to_solr_date_format(last_24h)} TO *]",
        page: 1,
        page_size: PAGE_SIZE,
        fields: %w[id system_mtime title publish]
      }
    end

    # This method will be replaced later
    def save_marc_locally(marc)
      File.open('marc_data.txt', 'a+') do |file|
        file.puts(marc)
        file.puts('-----')
      end
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
