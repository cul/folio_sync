# frozen_string_literal: true

module FolioSync::Exceptions
  class FolioSyncException < StandardError; end

  class ArchivesSpaceRequestError < FolioSyncException; end

  class FolioRequestError < FolioSyncException; end

  class InvalidDatabaseState < FolioSyncException; end

  class JobExecutionStartTimeoutError < FolioSyncException; end
  class JobExecutionInactivityTimeoutError < FolioSyncException; end
end
