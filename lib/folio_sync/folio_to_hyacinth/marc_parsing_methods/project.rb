# frozen_string_literal: true

module FolioSync
  module FolioToHyacinth
    module MarcParsingMethods
      module Project
        extend ActiveSupport::Concern

        included do
          register_parsing_method :add_project
        end

        def add_project(marc_record, _mapping_ruleset)
          existing_project = digital_object_data.fetch('project', {})['string_key']
          project_code = extract_project_code_from_marc(marc_record)

          return if project_code.nil?

          # For now, we'll log a message if there's an attempt to change the project
          if (existing_project != project_code) && !existing_project.nil?
            puts "Updating projects is not supported. Falling back to the current project: #{existing_project}"
          end

          create_project_data(project_code) if existing_project.nil?
        end

        def extract_project_code_from_marc(marc_record)
          marc_record.fields('965').each do |field|
            next unless field['p']

            project_code = field['p'].strip
            project_label = Rails.configuration.folio_to_hyacinth['project_mappings'][project_code.to_sym]

            return project_code if project_label

            log_invalid_project_code(project_code)
          end
          nil
        end

        # To set the project, we only need the project code, everything else is handled in Hyacinth
        # We check for valid project codes by looking them up in the configuration
        def create_project_data(project_code)
          digital_object_data['project'] = { 'string_key' => project_code }
        end

        def log_invalid_project_code(project_code)
          error_message = "Unrecognized project code '#{project_code}' for record with CLIO ID #{self.clio_id}"
          puts error_message
          self.errors << error_message
        end
      end
    end
  end
end
