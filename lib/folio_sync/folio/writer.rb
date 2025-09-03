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

      def check_out_item_by_barcode(barcode)
        payload = {
          "itemBarcode": barcode,
          "userBarcode": 'RBXMDTD001', # TODO: In the future, this should be configurable
          "servicePointId": '014ba39e-21cc-4f81-9296-08a741ed46b7', # TODO: In the future, this should be configurable
        }

        @client.post('/circulation/check-out-by-barcode', payload)
      end
    end
  end
end
