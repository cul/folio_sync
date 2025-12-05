# frozen_string_literal: true

class FolioSync::FolioToHyacinth::MarcProcessor
  def initialize(marc_file_path)
    @marc_file_path = marc_file_path
    @logger = Logger.new($stdout)
    @syncing_errors = []
  end

  def create_and_sync_hyacinth_record!
    folio_hrid = extract_hrid_from_filename(@marc_file_path)
    hyacinth_results = fetch_hyacinth_results(@marc_file_path)
    @logger.info("Found #{hyacinth_results.length} Hyacinth records for FOLIO HRID #{folio_hrid}")

    case hyacinth_results.length
    when 0
      create_new_hyacinth_record(@marc_file_path, folio_hrid)
    when 1
      update_existing_hyacinth_record(@marc_file_path, hyacinth_results.first, folio_hrid)
    else
      handle_multiple_records_error(folio_hrid)
    end
  rescue StandardError => e
    @logger.error("Failed to process #{folio_hrid}: #{e.message}")
    @syncing_errors << "Error processing #{folio_hrid}: #{e.message}"
  end

  def update_existing_hyacinth_record(marc_file_path, existing_record, folio_hrid)
    @logger.info("Updating existing Hyacinth record for #{folio_hrid}")

    preserved_data = { 'identifiers' => existing_record['identifiers'] }
    updated_record = FolioToHyacinthRecord.new(marc_file_path, preserved_data)

    response = FolioSync::Hyacinth::Client.instance.update_existing_record(
      existing_record['pid'],
      updated_record.digital_object_data,
      publish: true
    )

    @logger.info("Updated record #{existing_record['pid']}: #{response.inspect}")
    response
  end

  def handle_multiple_records_error(folio_hrid)
    error_message = "Multiple Hyacinth records found for FOLIO HRID #{folio_hrid}"
    @logger.error(error_message)
    @syncing_errors << error_message
  end

  def fetch_hyacinth_results(marc_file_path)
    folio_hrid = File.basename(marc_file_path, '.mrc')
    potential_clio_identifier = "clio#{folio_hrid}"
    client = FolioSync::Hyacinth::Client.instance
    client.find_by_identifier(potential_clio_identifier,
                              { f: { digital_object_type_display_label_sim: ['Item'] } })
  end

  def extract_hrid_from_filename(marc_file_path)
    File.basename(marc_file_path, '.mrc')
  end

  def create_new_hyacinth_record(marc_file_path, folio_hrid)
    @logger.info("Creating new Hyacinth record for #{folio_hrid}")

    new_record = FolioToHyacinthRecord.new(marc_file_path)
    puts "Digital object data: #{new_record.digital_object_data}"

    response = FolioSync::Hyacinth::Client.instance.create_new_record(
      new_record.digital_object_data,
      publish: true
    )

    @logger.info("Created record for #{folio_hrid}: #{response.inspect}")
    response
  end
end
