# frozen_string_literal: true

module FolioSync
  module FolioToHyacinth
    class MarcDownloader
      def initialize
        # @folio_reader = FolioSync::Folio::Reader.new
        @folio_client = FolioSync::Folio::Client.instance
        @downloading_errors = []
      end

      def retrieve_paginated_source_records(modified_since_utc, &block)
        params = {
          limit: 100,
          updatedAfter: '2025-09-26T15:35:32Z',
          offset: 0
        }

        loop do
          response = @folio_client.get('source-storage/source-records', params)

          puts "Retrieved another page of source records: offset=#{params[:offset]}"
          puts "There are #{response['sourceRecords'].length} records in this page, totalRecords=#{response['totalRecords']}"
          yield(response['sourceRecords']) if block_given?

          break if (params[:offset] + params[:limit]) >= response['totalRecords']

          params[:offset] += params[:limit]
        end
      end

      # Downloads all SRS MARC bibliographic records that have a 965 field that has a subfield $a value of '965hyacinth' AND were modified since the given `modified_since` Time.
      # A modified_since value of `nil` means that we want to download ALL '965hyacinth' records, regardless of modification time.
      def download_965hyacinth_marc_records(last_x_hours = nil)
        modified_since = Time.now.utc - (3600 * last_x_hours) if last_x_hours
        modified_since_utc = modified_since&.utc&.iso8601
        puts "Modified since: #{modified_since_utc}"

        retrieve_paginated_source_records(modified_since_utc) do |source_records|
          source_records.each do |source_record|
            puts "Source record ID is #{source_record['recordId']}"
          end
        end

        # @folio_client.get('source-storage/source-records',
        #                   { limit: 8, updatedAfter: modified_since_utc }).each do |source_record|
        #   puts source_record
        # end
      end

      # Downloads a single SRS MARC record to the download directory.  Raises an exception if the record with the given `folio_hrid` does NOT have at least one 965 field with a subfield $a value of '965hyacinth'.
      # def download_single_965hyacinth_marc_record(folio_hrid)
      # end
    end
  end
end
