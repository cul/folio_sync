# frozen_string_literal: true

# This error class is used to represent errors encountered while linking ArchivesSpace resources
# to FOLIO records. This involves issues with updating ASpace records with FOLIO HRIDs
# or failing to update pending_status in the database.
class FolioSync::Errors::LinkingError
  attr_reader :resource_uri, :message

  def initialize(resource_uri:, message:)
    @resource_uri = resource_uri
    @message = message
  end
end
