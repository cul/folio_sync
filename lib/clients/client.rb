module Clients
  class ArchivesSpaceClient
    def initialize(config)
      @client = ArchivesSpace::Client.new(config).login
    end

    def aspace_config
      ArchivesSpace::Configuration.new(
        base_uri: Rails.configuration.archivesspace["ASPACE_BASE_API"],
        username: Rails.configuration.archivesspace['ASPACE_DEV_API_USERNAME'],
        password: Rails.configuration.archivesspace['ASPACE_DEV_API_PASSWORD'],
        page_size: PAGE_SIZE,
        throttle: 0,
        verify_ssl: false,
        timeout: TIMEOUT
      )
    end

    def get_all_repositories
      response = @client.get("repositories")
      handle_response(response, "Error fetching repositories")
    end
  
    def fetch_resources_for_repo(repo_id)
      last_24h = Time.now.utc - ONE_DAY_IN_SECONDS
      query_params = build_query_params(last_24h)
  
      retrieve_paginated_resources(repo_id, query_params) do |resource|
        resource_id = extract_id(resource["uri"])
        fetch_and_save_marc(repo_id, resource_id)
      end
    end

    # def get_resources(repo_id, query_params)
    #   @client.get("repositories/#{repo_id}/search", query_params)
    # end

    # def get_marc(repo_id, resource_id)
    #   @client.get("repositories/#{repo_id}/resources/marc21/#{resource_id}.xml")
    # end
  end
end