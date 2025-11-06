# frozen_string_literal: true

module FolioSync
  module FolioToHyacinth
    module MarcParsingMethods
      module Project
        extend ActiveSupport::Concern

        MARC_PROJECT_FIELD = '965'
        PROJECT_SUBFIELD_CODE = 'p'

        included do
          register_parsing_method :add_project
        end

        # Adds project information to the digital_object_data based on MARC 965$p fields.
        # If multiple 965$p fields are present, the first is treated as the primary project,
        # and any additional ones are added as other projects.
        def add_project(marc_record, _mapping_ruleset)
          project_string_keys = extract_all_project_string_keys_from_marc(marc_record)

          return if project_string_keys.empty?

          # For now, we'll log a message if there's an attempt to change the project
          unless new_record?
            puts 'Updating projects is not supported. Falling back to the current project.'
            return
          end

          assign_projects(project_string_keys)
        end

        private

        def extract_all_project_string_keys_from_marc(marc_record)
          project_keys = []

          marc_record.fields(MARC_PROJECT_FIELD).each do |field|
            project_keys.concat(extract_project_subfields(field))
          end

          project_keys
        end

        def extract_project_subfields(field)
          field.subfields
               .select { |subfield| subfield.code == PROJECT_SUBFIELD_CODE }
               .map { |subfield| subfield.value.strip }
               .reject(&:empty?)
        end

        def assign_projects(project_string_keys)
          primary_project = project_string_keys.first
          other_projects = project_string_keys[1..]

          create_project_data(primary_project)

          return unless new_record? && other_projects.any?

          create_other_project_data(other_projects)
        end

        def create_project_data(project_string_key)
          digital_object_data['project'] = { 'string_key' => project_string_key }
        end

        def create_other_project_data(other_project_keys)
          return if other_project_keys.empty?

          digital_object_data['other_project'] = other_project_keys.map do |key|
            {
              'other_project_term' => {
                'uri' => "info:hyacinth.library.columbia.edu/projects/#{key}"
              }
            }
          end
        end
      end
    end
  end
end
