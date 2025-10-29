# frozen_string_literal: true

module FolioSync
  module FolioToHyacinth
    module MarcParsingMethods
      module Project
        extend ActiveSupport::Concern

        included do
          register_parsing_method :add_project
        end

        def add_project(marc_record, mapping_ruleset)
          # TODO: Reconcile existing project logic for existing records

          project_field = marc_record['965']
          project_code = project_field['b'] if project_field

          @digital_object_data.merge!(
            'project' => { "string_key": project_code }
          )
        end
      end
    end
  end
end
