class FOLIOSynchronizer
  ONE_DAY_IN_SECONDS = 24 * 60 * 60
  PAGE_SIZE = 20

  def initialize
    @logger = Logger.new($stdout) # Ensure logger is initialized first

    begin
      @aspace_client = ArchivesSpace::Client.new(Config::ArchivesSpaceConfig.build).login
    rescue StandardError => e
      @logger.error("Failed to login to ArchivesSpace: #{e.message}")
      raise "ArchivesSpace login failed. Please check your configuration and credentials."
    end
  end

  # Main method to fetch MARC data for all repositories
  def fetch_recent_marc_resources
    get_all_repositories.each do |repo|
      next log_repository_skip(repo) unless repo["publish"]

      repo_id = extract_id(repo["uri"])
      fetch_resources_for_repo(repo_id)
    end
  end

  private

  def get_all_repositories
    response = @aspace_client.get("repositories")
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

  # Builds query parameters for fetching resources updated since the given timestamp.
  # The query includes unpublished resources and filters by system_mtime.
  # Returns a hash with query details including fields, page size, and the time range.
  def build_query_params(last_24h)
    # temp_date = "2025-04-01T00:00:00.000Z"
    # last_24h = Time.now.utc - (ONE_DAY_IN_SECONDS * 6)
    last_24 = Time.now.utc - ONE_DAY_IN_SECONDS # Use this line to get the last 24h date, wrap it in time_to_solr_date_format

    # Include unpublished resources; this could change for other instances
    {
      query: {
        q: "primary_type:resource suppressed:false system_mtime:[#{time_to_solr_date_format(last_24h)} TO *]",
        page: 1,
        page_size: PAGE_SIZE,
        fields: %w[id system_mtime title publish]
      }
    }
  end

  def retrieve_paginated_resources(repo_id, query_params)
    loop do
      response = @aspace_client.get("repositories/#{repo_id}/search", query_params)
      unless response.status_code == 200
        @logger.error("Error fetching resources: #{response.body}")
      end

      data = response.parsed
      log_pagination(data)
      data["results"].each do |resource| 
        @logger.info("Processing resource: #{resource['title']} (system_mtime: #{resource['system_mtime']}) (ID: #{resource['id']} - #{resource['publish']})")
        yield(resource) 
      end

      break if data["this_page"] >= data["last_page"]

      current_page = data["this_page"]
      query_params[:query][:page] = current_page + 1
    end
  end

  def fetch_and_save_marc(repo_id, resource_id)
    response = @aspace_client.get("repositories/#{repo_id}/resources/marc21/#{resource_id}.xml")
    if response.status_code == 200 && response.parsed.present?
      save_marc_locally(response.parsed)
    else
      @logger.error("Failed to fetch MARC data for resource #{resource_id}: #{response.body}")
    end
  end

  # This method will be replaced later
  def save_marc_locally(marc)
    File.open("marc_data.txt", "a+") do |file|
      file.puts(marc)
      file.puts("-----")
    end
  end

  def time_to_solr_date_format(time)
    time.utc.strftime('%Y-%m-%dT%H:%M:%S.%LZ')
  end

  def extract_id(uri)
    uri.split("/").last
  end

  def log_repository_skip(repo)
    @logger.info("Repository #{repo['uri']} is not published, skipping...")
  end

  def log_pagination(data)
    @logger.info("Page #{data['this_page']} of #{data['last_page']} pages")
  end

  def handle_response(response, error_message)
    if response.status_code == 200
      response.parsed
    else
      @logger.error("#{error_message}: #{response.body}")
      []
    end
  end
end