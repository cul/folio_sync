module FolioSync
  module Folio
    class Writer
      def initialize
        @client = FolioSync::Folio::Client.instance
      end

      # TODO: Call the FOLIO API to create/update a record
      def create_or_update_folio_record(marc_record)
      end
    end
  end
end