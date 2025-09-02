# frozen_string_literal: true

module FolioSync
  module Folio
    class ItemHoldUpdater
      def initialize
        @folio_reader = FolioSync::Folio::Reader.new
        @folio_writer = FolioSync::Folio::Writer.new
        @updater_errors = []
      end

      def remove_permanent_holds_from_items
        items_to_check_out = @folio_reader.retrieve_circulation_requests

        return if items_to_check_out.empty?

        items_to_check_out.each do |item|
          @folio_writer.check_out_item_by_barcode(item['item']['barcode'])
        rescue StandardError => e
          @updater_errors << "Error removing permanent hold from item with barcode #{item['item']['barcode']}: #{e.message}"
        end
      end
    end
  end
end
