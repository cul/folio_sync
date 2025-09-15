# frozen_string_literal: true

module FolioSync
  module Folio
    class HoldingsCreator
      def initialize(folio_writer)
        @folio_writer = folio_writer || FolioSync::Folio::Writer.new
      end

      def create_holdings_for_instance(instance_id, holdings_metadata)
        validate_holdings_metadata!(holdings_metadata)
        
        permanent_location_id = resolve_location_id(holdings_metadata[:permanent_location])
        
        Rails.logger.info("Creating holdings record for instance #{instance_id} with call number: #{holdings_metadata[:holdings_call_number]}")
        
        @folio_writer.create_holdings_record(
          instance_id,
          holdings_metadata[:holdings_call_number],
          permanent_location_id
        )
        
        Rails.logger.info("Successfully created holdings record for instance #{instance_id}")
      rescue StandardError => e
        Rails.logger.error("Failed to create holdings for instance #{instance_id}: #{e.message}")
        raise "Holdings creation failed for instance #{instance_id}: #{e.message}"
      end

      private

      def validate_holdings_metadata!(metadata)
        required_fields = [:holdings_call_number, :permanent_location]
        missing_fields = required_fields.select { |field| metadata[field].blank? }
        
        return if missing_fields.empty?
        
        raise ArgumentError, "Missing required holdings metadata: #{missing_fields.join(', ')}"
      end

      def resolve_location_id(location_code)
        location_id = Rails.configuration.folio_holdings[:location_codes][location_code.to_sym]
        
        raise ArgumentError, "Unknown location code: #{location_code}" if location_id.blank?
        
        location_id
      end
    end
  end
end