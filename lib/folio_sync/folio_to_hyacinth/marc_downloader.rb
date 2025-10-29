# frozen_string_literal: true

class FolioSync::FolioToHyacinth::MarcDownloader
  attr_reader :downloading_errors

  def initialize
    @folio_client = FolioSync::Folio::Client.instance
    @folio_reader = FolioSync::Folio::Reader.new
    @downloading_errors = []
  end

  # Downloads all SRS MARC bibliographic records that have a 965 field that has a subfield $a value of '965hyacinth'
  # AND were modified within the last `last_x_hours` hours.
  # A modified_since value of `nil` means that we want to download ALL '965hyacinth' records, regardless of modification time.
  def download_965hyacinth_marc_records(last_x_hours = nil)
    modified_since = Time.now.utc - (3600 * last_x_hours) if last_x_hours
    modified_since_utc = modified_since&.utc&.iso8601
    Rails.logger.info(
      "Downloading MARC with 965hyacinth#{modified_since_utc ? " modified since: #{modified_since_utc}" : ' (all records)'}"
    )

    @folio_client.find_source_marc_records(modified_since: modified_since_utc, with_965_value: '965hyacinth') do |parsed_record|
      # The returned MARC record has been filtered to include records with "965hyacinth" identifiers
      # but we want to double-check that the identifier lives in the 965$a field.
      if has_965hyacinth_field?(parsed_record)
        begin
          save_marc_record_to_file(parsed_record)
        rescue StandardError => e
          record_id = extract_id(parsed_record) || 'unknown'
          error_message = "Failed to save MARC record #{record_id}: #{e.message}"
          @downloading_errors << error_message
          Rails.logger.error(error_message)
        end
      end
    end
  end

  # @param [Hash] marc_record A MARC record represented as a Hash
  def has_965hyacinth_field?(marc_record)
    fields = marc_record['fields']

    fields.any? do |field|
      next unless field['965']

      field['965']['subfields']&.any? { |subfield| subfield['a'] == '965hyacinth' }
    end
  end

  def save_marc_record_to_file(marc_record)
    config = Rails.configuration.folio_to_hyacinth
    filename = extract_id(marc_record)

    raise FolioSync::Exceptions::Missing001Field, 'MARC record is missing required 001 field' if filename.nil?

    file_path = File.join(config[:download_directory], "#{filename}.mrc")
    formatted_marc = MARC::Record.new_from_hash(marc_record)

    Rails.logger.info("Saving MARC record with 001=#{filename} to #{file_path}")
    File.binwrite(file_path, formatted_marc.to_marc)
  end

  # Downloads a single SRS MARC record to the download directory.  Raises an exception if the record with the given `folio_hrid`
  # does NOT have at least one 965 field with a subfield $a value of '965hyacinth'.
  def download_single_965hyacinth_marc_record(folio_hrid)
    source_record = @folio_client.find_source_record(instance_record_hrid: folio_hrid)
    marc_record = source_record['parsedRecord']['content'] if source_record

    unless has_965hyacinth_field?(marc_record)
      raise "Source record with HRID #{folio_hrid} doesn't have a 965 field with subfield $a value of '965hyacinth'."
    end

    save_marc_record_to_file(marc_record)
  end

  def extract_id(marc_record)
    field_001 = marc_record['fields']&.find { |f| f['001'] }
    field_001 ? field_001['001'] : nil
  end
end
