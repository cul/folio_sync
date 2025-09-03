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

      def get_marc_record_as_xml(hrid)
        record = get_marc_record(hrid)
        return nil if record.nil?

        record&.to_xml_string
      end

      def get_instance_by_id(instance_id)
        @client.find_instance_record(instance_record_id: instance_id)
      end

      # Query must be expressed as a CQL string: https://dev.folio.org/reference/glossary/#cql
      def retrieve_circulation_requests(repo_key)
        requester_barcode = Rails.configuration.folio_requests[:repos][repo_key.to_sym][:user_barcode]
        query = "requester.barcode=#{requester_barcode} and status=\"Open - Not yet filled\""

        @client.get('/circulation/requests', { limit: 2, query: query })['requests']
      end
    end
  end
end
