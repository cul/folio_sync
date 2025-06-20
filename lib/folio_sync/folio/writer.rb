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
    end
  end
end
