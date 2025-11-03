# frozen_string_literal: true

module FolioSync
  module FolioToHyacinth
    module MarcParsingMethods
      module Identifiers
        extend ActiveSupport::Concern

        included do
          register_parsing_method :add_identifiers
        end

        def add_identifiers(_marc_record, _mapping_ruleset)
          digital_object_data['identifiers'] ||= []
          digital_object_data['identifiers'] << "clio#{self.clio_id}" unless self.clio_id.nil?
          digital_object_data['identifiers'].uniq!
        end
      end
    end
  end
end
