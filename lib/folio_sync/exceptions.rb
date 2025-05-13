# frozen_string_literal: true

module FolioSync::Exceptions
  class FolioSyncException < StandardError; end
  # class DownloadError < StandardError; end
  # class SyncError < StandardError; end

  class ArchivesSpaceRequestError < FolioSyncException; end

  class FolioRequestError < FolioSyncException; end
end
