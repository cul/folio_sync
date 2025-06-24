# frozen_string_literal: true

class FolioSync::Errors::SyncingError
  attr_reader :resource_uri, :message

  def initialize(message:, resource_uri: nil)
    @resource_uri = resource_uri
    @message = message
  end
end
