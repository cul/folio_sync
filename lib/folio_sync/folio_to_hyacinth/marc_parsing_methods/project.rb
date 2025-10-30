# frozen_string_literal: true

module FolioSync
  module FolioToHyacinth
    module MarcParsingMethods
      module Project
        HYACINTH_2_URI_TEMPLATE = 'info:hyacinth.library.columbia.edu/projects/%s'.freeze

        extend ActiveSupport::Concern

        included do
          register_parsing_method :add_project
        end

        def add_project(marc_record, mapping_ruleset)
          existing_project = digital_object_data.fetch('project', {})['string_key']
          project_code = extract_project_code_from_marc(marc_record)

          return if project_code.nil?

          if existing_project != project_code 
            puts "Updating projects is not supported. Falling back to the current project: #{existing_project}" unless existing_project.nil?
          end

          create_project_data(project_code) if existing_project.nil?
        end

        def extract_project_code_from_marc(marc_record)
          marc_record.fields('965').each do |field|
            next unless field['p']

            project_code = field['p'].strip
            project_label = Rails.configuration.folio_to_hyacinth['project_mappings'][project_code.to_sym]
            
            if project_label
              return project_code
            else
              log_invalid_project_code(project_code)
            end
          end
          nil
        end

        def create_project_data(project_code)
          project_label = Rails.configuration.folio_to_hyacinth['project_mappings'][project_code.to_sym]

          digital_object_data['project'] = {
            'string_key' => project_code,
            # 'uri' => HYACINTH_2_URI_TEMPLATE % project_code,
            # 'display_label' => project_label
          }
        end

        def log_invalid_project_code(project_code)
          error_message = "Unrecognized project code '#{project_code}' in MARC record #{self.clio_id}"
          puts error_message
          self.errors << error_message
        end
      end
    end
  end
end
