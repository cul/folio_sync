# frozen_string_literal: true

module FolioSync
  module ArchivesSpaceToFolio
    class MarcRecordEnhancer
      attr_reader :marc_record, :hrid

      def initialize(aspace_marc_path, folio_marc_path, hrid, _instance_key)
        @hrid = hrid

        aspace_record = MARC::XMLReader.new(aspace_marc_path, parser: 'nokogiri')
        folio_record = nil

        folio_record = MARC::XMLReader.new(folio_marc_path, parser: 'nokogiri') if hrid

        @marc_record = aspace_record.first
        @folio_marc = folio_record.first
      end

      def enhance_marc_record!
        Rails.logger.debug 'Processing...'

        begin
          add_controlfield_001 if @hrid
          add_controlfield_003
          merge_035_fields if @hrid
          update_datafield_100
          update_datafield_856
          add_965_no_export_auth
          remove_corpname_punctuation
        rescue StandardError => e
          raise "Error enhacing ArchivesSpace MARC record: #{e.message}"
        end

        @marc_record
      end

      # Add hrid to controlfield 001 if it doesn't exist
      def add_controlfield_001
        return if @marc_record['001']

        ctrl_field = MARC::ControlField.new('001', @hrid)
        @marc_record.append(ctrl_field)
      end

      # Add NNC to controlfield 003 if it doesn't exist
      def add_controlfield_003
        return if @marc_record['003']

        ctrl_field = MARC::ControlField.new('003', 'NNC')
        @marc_record.append(ctrl_field)
      end

      # Merge 035 fields from ASpace and FOLIO MARC records
      # And remove any duplicate 035 fields (fields with the same indicator and subfield values)
      def merge_035_fields
        aspace_035_fields = @marc_record.fields('035')
        folio_035_fields = @folio_marc.fields('035')

        # Combine all 035 fields into a single array and ensure uniqueness
        combined_035_fields = (aspace_035_fields + (folio_035_fields || [])).uniq do |field|
          # Uniqueness is determined by the tag, indicators, and subfield values
          [field.tag, field.indicator1, field.indicator2, field.subfields.map { |sf| [sf.code, sf.value] }]
        end

        @marc_record.fields.delete_if { |field| field.tag == '035' }
        combined_035_fields.each { |field| @marc_record.append(field) }
        puts @marc_record
      end

      # Update datafield 100 - remove trailing punctuation from subfield d and remove subfield e
      def update_datafield_100
        field_100 = @marc_record['100']
        return unless field_100

        field_100.subfields.delete_if { |sf| sf.code == 'e' }

        field_100.subfields.each do |subfield|
          subfield.value = remove_trailing_punctuation(subfield.value) if subfield.code == 'd'
        end
      end

      # Update datafield 856 - remove subfield z and add subfield 3 with "Finding aid"
      def update_datafield_856
        field_856 = @marc_record['856']
        return unless field_856

        field_856.subfields.delete_if { |sf| sf.code == 'z' }
        subfield_3 = field_856.subfields.find { |sf| sf.code == '3' }

        if subfield_3
          subfield_3.value = 'Finding aid'
        else
          field_856.append(MARC::Subfield.new('3', 'Finding aid'))
        end
      end

      # Add 965 field
      def add_965_no_export_auth
        field_965 = MARC::DataField.new('965', ' ', ' ', ['a', '965noexportAUTH'])
        @marc_record.append(field_965)
      end

      # Processes corpname punctuation in 110 and 610 datafields
      def remove_corpname_punctuation
        field_110 = @marc_record['110']
        process_corpname_datafield(field_110) if field_110

        @marc_record.fields.each_by_tag('610') do |field_610|
          process_corpname_datafield(field_610)
        end
      end

      # Processes a corpname datafield (110 or 610) to remove trailing commas from subfields a and b.
      def process_corpname_datafield(field)
        subfields_a = field.subfields.select { |sf| sf.code == 'a' }

        return unless subfields_a.any?

        subfields_b = field.subfields.select { |sf| sf.code == 'b' }
        if subfields_b.empty?
          subfields_a.each do |subfield|
            subfield.value = remove_trailing_commas(subfield.value)
          end
        else
          subfields_b.each do |subfield|
            subfield.value = remove_trailing_commas(subfield.value)
          end
        end
      end

      def remove_trailing_commas(value)
        value.gsub(/[.]$/, '')
      end

      def remove_trailing_punctuation(value)
        value.gsub(/[,.]$/, '')
      end
    end
  end
end
