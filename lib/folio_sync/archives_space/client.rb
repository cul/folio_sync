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

  def get_all_repositories
    response = self.get("repositories")
    handle_response(response, "Error fetching repositories")
  end

  def retrieve_paginated_resources(repo_id, query_params)
    loop do
      response = self.get("repositories/#{repo_id}/search", query_params)
      handle_response(response, "Error fetching resources")

      data = response.parsed
      yield(data["results"]) if block_given?

      break if data["this_page"] >= data["last_page"]

      query_params[:query][:page] += 1
    end
  end

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