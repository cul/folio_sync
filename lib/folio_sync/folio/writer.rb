# frozen_string_literal: true

module FolioSync
  module Folio
    class Writer
      def initialize
        @client = FolioSync::Folio::Client.instance
      end

      def update_instance_record(instance_id, instance_record)
        @client.put("/instance-storage/instances/#{instance_id}", instance_record)
      end

      def check_out_item_by_barcode(barcode, repo_key)
        folio_requests_config = Rails.configuration.folio_requests[:repos][repo_key.to_sym]

        payload = {
          "itemBarcode": barcode,
          "userBarcode": folio_requests_config[:user_barcode],
          "servicePointId": folio_requests_config[:service_point_id]
        }

        @client.post('/circulation/check-out-by-barcode', payload)
      end

      def create_holdings_record(instance_id, holdings_call_number, permanent_location_id)
        payload = build_holdings_payload(instance_id, holdings_call_number, permanent_location_id)
        puts "Before creating holdings with payload #{payload} for instance #{instance_id}"

        res = @client.post('holdings-storage/holdings', payload)
        puts "After creating holdings, response is #{res}"
      end

      private

      def build_holdings_payload(instance_id, holdings_call_number, permanent_location_id)
        holdings_config = Rails.configuration.folio_holdings

        {
          "instanceId": instance_id,
          "permanentLocationId": permanent_location_id,
          "callNumber": holdings_call_number,
          "sourceId": holdings_config[:holdings_source_id],
          "holdingsTypeId": holdings_config[:holdings_type_id],
          "callNumberTypeId": holdings_config[:holdings_call_number_type_id]
        }
      end
    end
  end
end
