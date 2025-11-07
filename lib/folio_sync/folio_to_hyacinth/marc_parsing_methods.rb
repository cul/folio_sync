# frozen_string_literal: true

module FolioSync
  module FolioToHyacinth
    module MarcParsingMethods
      extend ActiveSupport::Concern

      module ClassMethods
        def registered_parsing_methods
          @registered_parsing_methods ||= []
        end

        def register_parsing_method(method_name)
          @registered_parsing_methods ||= []
          @registered_parsing_methods << method_name.to_sym
        end
      end
    end
  end
end
