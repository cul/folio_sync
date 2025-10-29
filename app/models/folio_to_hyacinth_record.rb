# frozen_string_literal: true

class FolioToHyacinthRecord
  include FolioSync::FolioToHyacinth::MarcParsingMethods
  include FolioSync::FolioToHyacinth::MarcParsingMethods::ClioIdentifier
  include FolioSync::FolioToHyacinth::MarcParsingMethods::Title
  include FolioSync::FolioToHyacinth::MarcParsingMethods::Project
  
  attr_reader :digital_object_data, :errors

  def initialize(initial_marc_record_path)
    puts "Initializing FolioToHyacinthRecord with MARC record at path: #{initial_marc_record_path}"
    reader = MARC::Reader.new(initial_marc_record_path)
    @marc_record = reader.first
    @digital_object_data = minimal_data_for_record
    @errors = []

    prepare_hyacinth_record(@marc_record)
  end

  def dynamic_field_data
    @digital_object_data['dynamic_field_data'] ||= {}
  end

  def minimal_data_for_record
    {
      'digital_object_type' => { 'string_key' => 'item' },
      'dynamic_field_data' => {},
      'identifiers' => []
    }
  end

  # Parses the given marc_record and extracts data of interest, populating this object's internal digital_object data.
  # Merges data from this marc record into the underlying digital_object_data fields
  def prepare_hyacinth_record(marc_record)
    self.class.registered_parsing_methods.each do |method_name|
      args = [method_name, marc_record, @mapping_ruleset]
      self.send(*args)
    end
  rescue StandardError => e
    puts "Error processing record: #{e.message}"
    self.errors << "An unhandled error was encountered while parsing record #{self.clio_id}: #{e.message}\n\t#{e.backtrace.join("\n\t")}"
  end
end
