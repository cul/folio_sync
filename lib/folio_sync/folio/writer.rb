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

        # @client.post('/circulation/check-out-by-barcode', payload)
      end
    end
  end
end
