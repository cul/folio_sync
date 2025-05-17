# frozen_string_literal: true

class FolioSync::Errors::DownloadingError
  attr_reader :resource_uri, :message

  def initialize(resource_uri:, message:)
    @resource_uri = resource_uri
    @message = message
  end
end
