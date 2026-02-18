# frozen_string_literal: true

class FolioSync::FolioToHyacinth::MarcProcessor
  attr_reader :syncing_errors

  def initialize(marc_file_path)
    @marc_file_path = marc_file_path
    @logger = Logger.new($stdout)
    @record_syncer = FolioSync::FolioToHyacinth::HyacinthRecordWriter.new
    @syncing_errors = []
  end

  def prepare_and_sync_folio_to_hyacinth_record!
    folio_hrid = extract_hrid_from_filename(@marc_file_path)
    existing_records = fetch_existing_hyacinth_records(folio_hrid)

    @logger.info("Found #{existing_records.length} Hyacinth records for FOLIO HRID: #{folio_hrid}")

    @record_syncer.sync(@marc_file_path, folio_hrid, existing_records)
    @syncing_errors.concat(@record_syncer.syncing_errors) if @record_syncer.syncing_errors.any?
  rescue StandardError => e
    @logger.error("Failed to process #{folio_hrid}: #{e.message}")
    @syncing_errors << "Error processing #{folio_hrid}: #{e.message}"
  end

  private

  def extract_hrid_from_filename(marc_file_path)
    File.basename(marc_file_path, '.mrc')
  end

  def fetch_existing_hyacinth_records(folio_hrid)
    potential_clio_identifier = "clio#{folio_hrid}"
    client = FolioSync::Hyacinth::Client.instance
    client.find_by_identifier(
      potential_clio_identifier,
      { f: { digital_object_type_display_label_sim: ['Item'] } }
    )
  end
end
