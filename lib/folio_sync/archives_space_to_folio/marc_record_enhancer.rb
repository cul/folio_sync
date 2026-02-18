# frozen_string_literal: true

module FolioSync
  module ArchivesSpaceToFolio
    class MarcRecordEnhancer
      attr_reader :marc_record, :hrid

      def initialize(aspace_marc_path, folio_marc_path, hrid, instance_key)
        @hrid = hrid
        @instance_key = instance_key

        aspace_record = MARC::XMLReader.new(aspace_marc_path, parser: 'nokogiri')
        # The final MARC record is mostly constructed from the ArchivesSpace MARC
        @marc_record = aspace_record.first
        @folio_marc = nil

        return unless folio_marc_path

        @folio_marc = MARC::XMLReader.new(folio_marc_path, parser: 'nokogiri').first
      end

      def enhance_marc_record!
        Rails.logger.debug 'Processing...'

        begin
          update_controlfield_001
          add_controlfield_003
          merge_035_fields
          update_datafield_099
          update_datafield_100
          update_datafield_856
          add_948_field if @instance_key == 'cul'
          add_965_no_export_auth
          remove_corpname_punctuation
        rescue StandardError => e
          raise "Error enhancing ArchivesSpace MARC record: #{e.message}"
        end

        @marc_record
      end

      # Update or remove controlfield 001 based on hrid presence
      def update_controlfield_001
        unless @hrid
          @marc_record.fields.delete_if { |field| field.tag == '001' }
          return
        end

        ctrl_field = @marc_record['001']
        if ctrl_field
          ctrl_field.value = @hrid
        else
          @marc_record.append(MARC::ControlField.new('001', @hrid))
        end
      end

      # Add NNC to controlfield 003 if it doesn't exist
      def add_controlfield_003
        return if @marc_record['003']

        ctrl_field = MARC::ControlField.new('003', 'NNC')
        @marc_record.append(ctrl_field)
      end

      # Merge 035 fields from ASpace and FOLIO MARC records
      # When folio record is present, combine fields from both records and ensure uniqueness
      # When folio record is not present, ensure ASpace 035 fields are retained
      def merge_035_fields
        aspace_035_fields = @marc_record.fields('035') || []
        folio_035_fields = @folio_marc&.fields('035') || []

        combined_035_fields = (aspace_035_fields + folio_035_fields).uniq do |field|
          # Uniqueness is determined by the tag, indicators, and subfield values
          [field.tag, field.indicator1, field.indicator2, field.subfields.map { |sf| [sf.code, sf.value] }]
        end

        @marc_record.fields.delete_if { |field| field.tag == '035' }
        combined_035_fields.each { |field| @marc_record.append(field) }
      end

      # For new FOLIO records (records without the hrid), remove datafield 099
      def update_datafield_099
        return if @hrid

        @marc_record.fields.delete_if { |field| field.tag == '099' }
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

      # OCLC sync support: Add or update datafield 948
      def add_948_field
        current_date = Time.now.utc.strftime('%Y%m%d')
        existing_oclc_field = find_folio_948_asoclc_field

        oclc_field = if existing_oclc_field
                       update_948_date(existing_oclc_field, current_date)
                     else
                       MARC::DataField.new('948', ' ', ' ',
                                           ['a', current_date],
                                           ['b', 'STATORGL'],
                                           ['d', 'ASOCLC'])
                     end

        @marc_record.append(oclc_field)
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

      def update_948_date(field, date)
        updated_field = MARC::DataField.new(
          field.tag,
          field.indicator1,
          field.indicator2,
          *field.subfields.map { |sf| [sf.code, sf.value] }
        )

        subfield_a = updated_field.subfields.find { |sf| sf.code == 'a' }
        if subfield_a
          subfield_a.value = date
        else
          updated_field.append(MARC::Subfield.new('a', date))
        end

        updated_field
      end

      def find_folio_948_asoclc_field
        return nil unless @folio_marc

        @folio_marc.fields('948').find do |field|
          subfield_d = field['d']
          subfield_d == 'ASOCLC'
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
