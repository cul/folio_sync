# frozen_string_literal: true

module FolioSync
  class FolioSynchronizer
    ONE_DAY_IN_SECONDS = 24 * 60 * 60
    PAGE_SIZE = 200

    def initialize
      @logger = Logger.new($stdout) # Ensure logger is initialized first
      @aspace_client = FolioSync::ArchivesSpace::Client.instance
      @folio_client = FolioSync::Folio::Client.instance
    end

    def fetch_and_sync_resources_to_folio
      fetch_and_save_recent_marc_resources
      sync_resources_to_folio
    end

    def sync_resources_to_folio
      # Iterate over all files in the tmp/marc_files directory
      # Use foreach for better performance with large directories
      marc_dir = Rails.root.join('tmp/marc_files')
      Dir.foreach(marc_dir) do |file|
        next if ['.', '..'].include?(file)

        puts "Processing file: #{file}"
        bib_id = File.basename(file, '.xml')
        @folio_client.create_or_update_folio_record(bib_id)
      end
    end

    def fetch_and_save_recent_marc_resources
      modified_since = Time.now.utc - (ONE_DAY_IN_SECONDS * 20)

      @aspace_client.get_all_repositories.each do |repo|
        next log_repository_skip(repo) unless repo['publish']

        repo_id = extract_id(repo['uri'])
        fetch_resources_in_repo_since_time_and_save_locally(repo_id, modified_since: modified_since)
      end
    end

    private

    def fetch_resources_in_repo_since_time_and_save_locally(repo_id, modified_since: nil)
      query_params = build_query_params(modified_since)

      @aspace_client.retrieve_paginated_resources(repo_id, query_params) do |resources|
        resources.each do |resource|
          log_resource_processing(resource)
          fetch_and_save_marc(repo_id, extract_id(resource['uri']), resource['identifier'])
        end
      end
    end

    def fetch_and_save_marc(repo_id, resource_id, bib_id)
      marc_data = @aspace_client.fetch_marc_data(repo_id, resource_id)

      return unless marc_data

      puts "Saving MARC data locally... for resource with bibid: #{bib_id}"

      # ! To check: other instances might use the same bib_id
      file_path = Rails.root.join("tmp/marc_files/#{bib_id}.xml")
      File.binwrite(file_path, marc_data.body)
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
