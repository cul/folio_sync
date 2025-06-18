# frozen_string_literal: true

module FolioSync
  module Folio
    class Writer
      def initialize
        @client = FolioSync::Folio::Client.instance
      end

      def suppress_record_from_discovery(record_id, suppress_status)
        @client.put("/source-storage/records/#{record_id}/suppress-from-discovery?suppressStatus=#{suppress_status}")
      end
    end
  end
end
