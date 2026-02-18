# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FolioSync::FolioToHyacinth::MarcProcessor do
  let(:marc_file_path) { '/tmp/folio_to_hyacinth/downloaded_files/45678.mrc' }
  let(:instance) { described_class.new(marc_file_path) }
  let(:logger) { instance_double(Logger, info: nil, error: nil, debug: nil) }
  let(:record_syncer) { instance_double(FolioSync::FolioToHyacinth::HyacinthRecordWriter, syncing_errors: []) }
  let(:hyacinth_client) { instance_double(FolioSync::Hyacinth::Client) }
  let(:folio_hrid) { '45678' }

  before do
    allow(Logger).to receive(:new).and_return(logger)
    allow(FolioSync::FolioToHyacinth::HyacinthRecordWriter).to receive(:new).and_return(record_syncer)
    allow(FolioSync::Hyacinth::Client).to receive(:instance).and_return(hyacinth_client)
  end

  describe '#initialize' do
    it 'sets the marc_file_path' do
      expect(instance.instance_variable_get(:@marc_file_path)).to eq(marc_file_path)
    end

    it 'initializes a logger' do
      expect(instance.instance_variable_get(:@logger)).to eq(logger)
    end

    it 'initializes a record syncer' do
      expect(instance.instance_variable_get(:@record_syncer)).to eq(record_syncer)
    end

    it 'initializes syncing_errors as empty array' do
      expect(instance.syncing_errors).to eq([])
    end
  end

  describe '#prepare_and_sync_folio_to_hyacinth_record!' do
    let(:existing_records) { [] }

    before do
      allow(hyacinth_client).to receive(:find_by_identifier).and_return(existing_records)
      allow(record_syncer).to receive(:sync)
    end

    it 'extracts the HRID from the filename' do
      instance.prepare_and_sync_folio_to_hyacinth_record!
      expect(hyacinth_client).to have_received(:find_by_identifier).with(
        "clio#{folio_hrid}",
        { f: { digital_object_type_display_label_sim: ['Item'] } }
      )
    end

    it 'fetches existing Hyacinth records' do
      expect(hyacinth_client).to receive(:find_by_identifier).with(
        "clio#{folio_hrid}",
        { f: { digital_object_type_display_label_sim: ['Item'] } }
      )
      instance.prepare_and_sync_folio_to_hyacinth_record!
    end

    it 'logs the number of existing records found' do
      expect(logger).to receive(:info).with("Found 0 Hyacinth records for FOLIO HRID: #{folio_hrid}")
      instance.prepare_and_sync_folio_to_hyacinth_record!
    end

    it 'calls sync on the record syncer' do
      expect(record_syncer).to receive(:sync).with(marc_file_path, folio_hrid, existing_records)
      instance.prepare_and_sync_folio_to_hyacinth_record!
    end

    context 'when one existing record is found' do
      let(:existing_records) do
        [
          {
            'pid' => 'abc123',
            'identifiers' => [{ 'value' => 'clio45678' }]
          }
        ]
      end

      it 'logs the correct count' do
        expect(logger).to receive(:info).with("Found 1 Hyacinth records for FOLIO HRID: #{folio_hrid}")
        instance.prepare_and_sync_folio_to_hyacinth_record!
      end

      it 'passes existing records to syncer' do
        expect(record_syncer).to receive(:sync).with(marc_file_path, folio_hrid, existing_records)
        instance.prepare_and_sync_folio_to_hyacinth_record!
      end
    end

    context 'when multiple existing records are found' do
      let(:existing_records) do
        [
          { 'pid' => 'abc123' },
          { 'pid' => 'def456' }
        ]
      end

      it 'logs the correct count' do
        expect(logger).to receive(:info).with("Found 2 Hyacinth records for FOLIO HRID: #{folio_hrid}")
        instance.prepare_and_sync_folio_to_hyacinth_record!
      end
    end

    context 'when record syncer has no errors' do
      it 'does not add to syncing_errors' do
        instance.prepare_and_sync_folio_to_hyacinth_record!
        expect(instance.syncing_errors).to eq([])
      end
    end

    context 'when record syncer has errors' do
      let(:syncer_errors) { ['Failed to create record', 'Network timeout'] }

      before do
        allow(record_syncer).to receive(:syncing_errors).and_return(syncer_errors)
      end

      it 'concatenates sync errors to syncing_errors' do
        instance.prepare_and_sync_folio_to_hyacinth_record!
        expect(instance.syncing_errors).to eq(syncer_errors)
      end
    end

    context 'when an exception is raised' do
      let(:error_message) { 'Connection refused' }

      before do
        allow(hyacinth_client).to receive(:find_by_identifier).and_raise(StandardError.new(error_message))
      end

      it 'logs the error' do
        expect(logger).to receive(:error).with("Failed to process #{folio_hrid}: #{error_message}")
        instance.prepare_and_sync_folio_to_hyacinth_record!
      end

      it 'adds error to syncing_errors' do
        instance.prepare_and_sync_folio_to_hyacinth_record!
        expect(instance.syncing_errors).to include("Error processing #{folio_hrid}: #{error_message}")
      end
    end

    context 'when fetching existing records fails' do
      before do
        allow(hyacinth_client).to receive(:find_by_identifier).and_raise(StandardError.new('API error'))
      end

      it 'captures the error without calling sync' do
        instance.prepare_and_sync_folio_to_hyacinth_record!
        expect(record_syncer).not_to have_received(:sync)
        expect(instance.syncing_errors).to include(/Error processing #{folio_hrid}/)
      end
    end
  end

  describe '#extract_hrid_from_filename' do
    it 'extracts HRID from .mrc file' do
      result = instance.send(:extract_hrid_from_filename, '/tmp/downloads/45678.mrc')
      expect(result).to eq('45678')
    end
  end

  describe '#fetch_existing_hyacinth_records' do
    let(:clio_identifier) { "clio#{folio_hrid}" }
    let(:search_params) { { f: { digital_object_type_display_label_sim: ['Item'] } } }

    before do
      allow(hyacinth_client).to receive(:find_by_identifier).and_return([])
    end

    it 'constructs the correct clio identifier' do
      expect(hyacinth_client).to receive(:find_by_identifier).with(clio_identifier, search_params)
      instance.send(:fetch_existing_hyacinth_records, folio_hrid)
    end

    it 'searches for Item type records' do
      expect(hyacinth_client).to receive(:find_by_identifier).with(
        anything,
        { f: { digital_object_type_display_label_sim: ['Item'] } }
      )
      instance.send(:fetch_existing_hyacinth_records, folio_hrid)
    end

    it 'returns the search results' do
      expected_results = [{ 'pid' => 'test123' }]
      allow(hyacinth_client).to receive(:find_by_identifier).and_return(expected_results)
      
      result = instance.send(:fetch_existing_hyacinth_records, folio_hrid)
      expect(result).to eq(expected_results)
    end
  end
end