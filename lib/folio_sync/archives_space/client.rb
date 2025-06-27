# frozen_string_literal: true

class FolioSync::ArchivesSpace::Client < ArchivesSpace::Client
  def initialize(instance_key)
    instance_config = Rails.configuration.archivesspace[instance_key]
    raise ArgumentError, "No ArchivesSpace config for instance '#{instance_key}'" unless instance_config

    config = ArchivesSpace::Configuration.new({
      base_uri: instance_config[:base_url],
      username: instance_config[:username],
      password: instance_config[:password],
      timeout: instance_config[:timeout]
    })

    super(config)
    login
  end

  def fetch_all_repositories
    response = self.get('repositories')
    handle_response(response, 'Error fetching repositories')
    response.parsed
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
    query = query_params.dup # Duplicate query_params so we don't modify the original
    query[:page] ||= 1 # Ensure page is initialized

    loop do
      response = self.get("repositories/#{repo_id}/search", { query: query })
      handle_response(response, 'Error fetching resources')

      data = response.parsed
      Rails.logger.debug "Page: #{data['this_page']}, Total Pages: #{data['last_page']}"
      yield(data['results']) if block_given?

      break if data['this_page'] >= data['last_page']

      query[:page] += 1
    end
  end

  # This method is used only for a one-time manual step
  # to identify which ASpace resources have corresponding FOLIO records.
  def retrieve_resources_for_repository(repo_id, query_params)
    query = query_params.dup
    query[:page] ||= 1

    loop do
      puts "Page #{query[:page]} for repository #{repo_id}"
      response = self.get("repositories/#{repo_id}/resources", { query: query })
      handle_response(response, 'Error fetching resources')

      data = response.parsed
      Rails.logger.debug "Page: #{data['this_page']}, Total Pages: #{data['last_page']}"
      yield(data['results']) if block_given?

      # ! Temporarily only check the first 2 pages
      break if data['this_page'] >= data['last_page'] || query[:page] == 2

      query[:page] += 1
    end
  end

  # @param repo_id [String] The ID of the repository to fetch resources from.
  # @param resource_id [String] The ID of the resource to fetch MARC data for.
  #
  # @return [Hash] The XML MARC data for the resource.
  #
  # @raise [FolioSync::Exceptions::ArchivesSpaceRequestError] If the request fails.
  def fetch_marc_xml_resource(repo_id, resource_id)
    response = self.get("repositories/#{repo_id}/resources/marc21/#{resource_id}.xml")
    handle_response(response, "Failed to fetch MARC data for resource #{resource_id}")
    response.body
  end

  def fetch_resource(repo_id, resource_id)
    response = self.get("repositories/#{repo_id}/resources/#{resource_id}")
    handle_response(response, "Failed to fetch resource #{resource_id}")
    response.parsed
  end

  def update_resource(repo_id, resource_id, updated_data)
    response = self.post("repositories/#{repo_id}/resources/#{resource_id}", updated_data)
    handle_response(response, "Failed to update resource #{resource_id}")
  end

  def update_id_fields(repo_id, resource_id, new_id)
    old_resource = fetch_resource(repo_id, resource_id)
    updated_resource_data = old_resource.merge('id_0' => new_id, 'ead_id' => new_id)

    update_resource(repo_id, resource_id, updated_resource_data)
  end

  def update_string_1_field(repo_id, resource_id, new_string)
    old_resource = fetch_resource(repo_id, resource_id)
    user_defined = old_resource['user_defined'] || {}
    user_defined['string_1'] = new_string
    updated_resource_data = old_resource.merge('user_defined' => user_defined)

    update_resource(repo_id, resource_id, updated_resource_data)
  end

  private

  def handle_response(response, error_message)
    unless response.status_code == 200
      raise FolioSync::Exceptions::ArchivesSpaceRequestError, "#{error_message}: #{response.body}"
    end

    response
  end
end
