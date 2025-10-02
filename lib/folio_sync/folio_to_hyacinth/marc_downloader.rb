# frozen_string_literal: true

module FolioSync
  module FolioToHyacinth
    class MarcDownloader
      def initialize
        @folio_client = FolioSync::Folio::Client.instance
        @folio_reader = FolioSync::Folio::Reader.new
        @downloading_errors = []
      end

      def retrieve_paginated_source_records(modified_since_utc)
        params = {
          limit: 100,
          offset: 0
        }
        params[:updatedAfter] = modified_since_utc if modified_since_utc

        loop do
          response = @folio_client.get('source-storage/source-records', params)

          puts "New page: There are #{response['sourceRecords'].length} records in this page, totalRecords=#{response['totalRecords']}"

          if block_given?
            response['sourceRecords'].each do |source_record|
              yield(source_record['parsedRecord']['content']) if source_record['parsedRecord']['content']
            end
          end

          break if (params[:offset] + params[:limit]) >= response['totalRecords']

          params[:offset] += params[:limit]
        end
      end

      # Downloads all SRS MARC bibliographic records that have a 965 field that has a subfield $a value of '965hyacinth' AND were modified since the given `modified_since` Time.
      # A modified_since value of `nil` means that we want to download ALL '965hyacinth' records, regardless of modification time.
      def download_965hyacinth_marc_records(last_x_hours = nil)
        modified_since = Time.now.utc - (3600 * last_x_hours) if last_x_hours
        modified_since_utc = modified_since&.utc&.iso8601

        retrieve_paginated_source_records(modified_since_utc) do |parsed_record|
          if has_965hyacinth_field?(parsed_record)
            puts 'Found 965hyacinth field'
            save_marc_record_to_file(parsed_record)
          end
        end
      end

      # @param [Hash] marc_record A MARC record represented as a Hash (as returned in the 'parsedRecord' attribute of a source record)
      def has_965hyacinth_field?(marc_record)
        fields = marc_record['fields']

        fields.any? do |field|
          next unless field['965']

          field['965']['subfields']&.any? { |subfield| subfield['a'] == '965hyacinth' }
        end
      end

      def save_marc_record_to_file(marc_record)
        filename = marc_record['fields'].find { |f| f['001'] }['001']
        formatted_marc = MARC::Record.new_from_hash(marc_record)

        File.binwrite("tmp/#{filename}.mrc", formatted_marc)
      end

      # Downloads a single SRS MARC record to the download directory.  Raises an exception if the record with the given `folio_hrid`
      # does NOT have at least one 965 field with a subfield $a value of '965hyacinth'.
      def download_single_965hyacinth_marc_record(folio_hrid)
        source_record = @folio_client.find_source_record(instance_record_hrid: folio_hrid)
        marc_record = source_record['parsedRecord']['content'] if source_record

        unless has_965hyacinth_field?(marc_record)
          raise "Source record with HRID #{folio_hrid} doesn't have a 965 field with subfield $a value of '965hyacinth'. Not downloading."
        end

        save_marc_record_to_file(marc_record)
      end
    end
  end
end
