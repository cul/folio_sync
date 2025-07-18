# frozen_string_literal: true

# This error class is used to represent errors encountered
# while downloading MARC files from ArchivesSpace or FOLIO
class FolioSync::Errors::DownloadingError
  attr_reader :resource_uri, :message

  def initialize(resource_uri:, message:)
    @resource_uri = resource_uri
    @message = message
  end
end
