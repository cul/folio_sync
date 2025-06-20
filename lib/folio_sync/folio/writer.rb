# frozen_string_literal: true

module FolioSync
  module Folio
    class Writer
      def initialize
        @client = FolioSync::Folio::Client.instance
      end

      # def suppress_record_from_discovery(record_id, suppress_status)
      #   @client.put("/source-storage/records/#{record_id}/suppress-from-discovery?suppressStatus=#{suppress_status}")
      # end

      # def suppress_instance_from_discovery(instance_id, suppress_status)
      #   @client.put("/source-storage/records/#{instance_id}/suppress-from-discovery?suppressStatus=#{suppress_status}")
      # end
      #
      def suppress_record_from_instance_discovery(instance_id, instance_record)
        # Send the updated instance record as JSON to FOLIO
        @client.put("/instance-storage/instances/#{instance_id}", instance_record)
      end
    end
  end
end
