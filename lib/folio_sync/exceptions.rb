module FolioSync::Exceptions
  class FolioSyncException < StandardError; end
  
  class ArchivesSpaceRequestError < FolioSyncException; end
end