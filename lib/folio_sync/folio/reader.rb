module FolioSync
  module Folio
    class Reader
      def initialize
        @client = FolioSync::Folio::Client.instance
      end

      # @param hrid [String] The HRID (BIBID) of the instance record to fetch.
      def get_marc_record(hrid)
        # Returns Marc::Record
        @client.find_marc_record(instance_record_hrid: hrid)
      end
    end
  end
end