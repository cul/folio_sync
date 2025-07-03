# frozen_string_literal: true

# This error class is used to represent errors encountered while fetching resources from ArchivesSpace
class FolioSync::Errors::FetchingError
  attr_reader :resource_uri, :message

  def initialize(resource_uri:, message:)
    @resource_uri = resource_uri
    @message = message
  end
end
