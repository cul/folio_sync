# frozen_string_literal: true

module FolioSync
  module FolioToHyacinth
    module MarcParsingMethods
      module Title
        extend ActiveSupport::Concern

        included do
          register_parsing_method :add_title
        end

        def add_title(marc_record, mapping_ruleset)
          return if marc_record['245'].blank?

          non_sort_portion_length = marc_record['245'].indicator2.nil? ? 0 : marc_record['245'].indicator2.to_i
          title = extract_title(marc_record, mapping_ruleset)
          return if title.nil?

          dynamic_field_data['title'] ||= []
          dynamic_field_data['title'] << {
            'title_non_sort_portion' => title[0...non_sort_portion_length],
            'title_sort_portion' => title[non_sort_portion_length..]
          }
        end

        def extract_title(marc_record, mapping_ruleset)
          field = marc_record["245"]
          return nil if field.nil?

          title = field['a']
          case mapping_ruleset
          when 'carnegie_scrapbooks_and_ledgers', 'oral_history'
            title += " #{field['f']}" if field['f']
          else
            title += " #{field['b']}" if field['b']
            title += " #{field['f']}" if field['f']
            title += " #{field['n']}" if field['n']
            title += " #{field['p']}" if field['p']
          end

          StringCleaner.trailing_punctuation_and_whitespace(title)
        end
      end
    end
  end
end
