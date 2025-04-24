class FolioSync::ArchivesSpace::Client < ArchivesSpace::Client
  def self.instance
    unless @instance
      @instance = self.new(ArchivesSpace::Configuration.new({
        base_uri: Rails.configuration.archivesspace["ASPACE_BASE_API"],
        username: Rails.configuration.archivesspace["ASPACE_API_USERNAME"],
        password: Rails.configuration.archivesspace["ASPACE_API_PASSWORD"],
        timeout:  Rails.configuration.archivesspace["ASPACE_TIMEOUT"],
        verify_ssl: true
      }))
      @instance.login # logs in automatically when it is initialized
    end
    @instance
  end

  # ?? This method is the same as the one from ASpace gem,
  # should we still have it as a separate method? Or should we just call
  # get("repositories") in the synchronizer and handle the response there?
  def get_all_repositories
    response = self.get("repositories")
    handle_response(response, "Error fetching repositories")
  end

  # This method fetches all resources for a given repository
  # and yields them to the block for processing.
  # It handles pagination automatically.
  #
  # @param repo_id [String] The ID of the repository to fetch resources from.
  # @param query_params [Hash] The query parameters for the API request.
  #
  # @yield [Array] The array of resources fetched from the API.
  #
  # @return [void]
  def retrieve_paginated_resources(repo_id, query_params)
    query_params[:query][:page] ||= 1 # Ensure page is initialized
  
    loop do
      response = self.get("repositories/#{repo_id}/search", query_params)
      handle_response(response, "Error fetching resources")

      data = response.parsed
      puts "Page: #{data['this_page']}, Total Pages: #{data['last_page']}"
      yield(data["results"]) if block_given?

      break if data["this_page"] >= data["last_page"]

      query_params[:query][:page] += 1
    end
  end

  # ?? Same issue as get_all_repositories - should we keep this method
  # if we only add response handling
  # @param repo_id [String] The ID of the repository to fetch resources from.
  # @param resource_id [String] The ID of the resource to fetch MARC data for.
  #
  # @return [Hash] The parsed MARC data for the resource.
  #
  # @raise [StandardError] If the request fails or if the response is not valid.
  def fetch_marc_data(repo_id, resource_id)
    response = self.get("repositories/#{repo_id}/resources/marc21/#{resource_id}.xml")
    handle_response(response, "Failed to fetch MARC data for resource #{resource_id}")
  end

  private

  def handle_response(response, error_message)
    if response.status_code == 200
      response.parsed
    else
      raise "#{error_message}: #{response.body}"
    end
  end
end