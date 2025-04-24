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
end