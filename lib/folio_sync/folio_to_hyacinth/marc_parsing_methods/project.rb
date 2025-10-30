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
          project_string_key = extract_project_string_key_from_marc(marc_record)

          return if project_string_key.nil?

          # For now, we'll log a message if there's an attempt to change the project
          if (existing_project != project_string_key) && !existing_project.nil?
            puts "Updating projects is not supported. Falling back to the current project: #{existing_project}"
          end

          create_project_data(project_string_key) if existing_project.nil?
        end

        def extract_project_string_key_from_marc(marc_record)
          marc_record.fields('965').each do |field|
            next unless field['p']

            project_string_key = field['p'].strip
            return project_string_key unless project_string_key.empty?
          end
          nil
        end

        def create_project_data(project_string_key)
          digital_object_data['project'] = { 'string_key' => project_string_key }
        end
      end
    end
  end
end
