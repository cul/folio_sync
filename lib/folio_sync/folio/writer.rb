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

      def create_holdings_record(instance_id, holdings_call_number, permanent_location)
        puts "Permanent location is #{permanent_location}"
        location_map = {
          "NNC-RB": "f90d928c-e475-4d18-bd99-e0bf2c48de04"
        }

        payload = {
          "instanceId": instance_id,
          "sourceId": "f32d531e-df79-46b3-8932-cdd35f7a2264", # FOLIO source, alternative is MARC
          "permanentLocationId": location_map[permanent_location.to_sym],
          "holdingsTypeId": "03c9c400-b9e3-4a07-ac0e-05ab470233ed", # Monograph
          "callNumber": holdings_call_number
        }
        puts "Before creating holdings with payload #{payload} for instance #{instance_id}"

        res = @client.post('holdings-storage/holdings', payload)
        puts "After creating holdings, response is #{res}"
      end
    end
  end
end
