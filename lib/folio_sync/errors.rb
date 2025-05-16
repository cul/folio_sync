
module FolioSync::Errors
  class DownloadingError
    attr_reader :resource_uri, :message

    def initialize(resource_uri:, message:)
      @resource_uri = resource_uri
      @message = message
    end
  end

  class SyncingError
    attr_reader :bib_id, :message

    def initialize(bib_id:, message:)
      @bib_id = bib_id
      @message = message
    end
  end
end