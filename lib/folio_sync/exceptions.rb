# frozen_string_literal: true

module FolioSync::Exceptions
  class FolioSyncException < StandardError; end

  class ArchivesSpaceRequestError < FolioSyncException; end
end
