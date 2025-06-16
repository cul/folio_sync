# frozen_string_literal: true

module FolioSync
  module Folio
    class Reader
      def initialize
        @client = FolioSync::Folio::Client.instance
      end

      # @param hrid [String] The HRID (BIBID) of the instance record to fetch.
      def get_marc_record(hrid)
        source_record = @client.find_source_record(instance_record_hrid: hrid)
        return nil if source_record.nil?

        MARC::Record.new_from_hash(source_record['parsedRecord']['content'])
      end
    end
  end
end
