# Setting up the ArchivesSpace configuration
module Config
  class ArchivesSpaceConfig
    def self.build
      ArchivesSpace::Configuration.new(
        base_uri: Rails.configuration.archivesspace["ASPACE_BASE_API"],
        username: Rails.configuration.archivesspace["ASPACE_DEV_API_USERNAME"],
        password: Rails.configuration.archivesspace["ASPACE_DEV_API_PASSWORD"],
        page_size: 20,
        throttle: 0,
        verify_ssl: false,
        timeout: 60
      )
    end
  end
end