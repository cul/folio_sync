# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FolioSync::FolioToHyacinth::HyacinthRecordWriter do
  let(:instance) { described_class.new }
  let(:logger) { instance_double(Logger, info: nil, error: nil, debug: nil) }
  let(:hyacinth_client) { instance_double(FolioSync::Hyacinth::Client) }
  let(:marc_file_path) { '/tmp/folio_to_hyacinth/downloaded_files/12345678.mrc' }
  let(:folio_hrid) { '12345678' }

  before do
    allow(Logger).to receive(:new).and_return(logger)
    allow(FolioSync::Hyacinth::Client).to receive(:instance).and_return(hyacinth_client)
  end

  describe '#initialize' do
    it 'sets up a logger' do
      expect(instance.instance_variable_get(:@logger)).to eq(logger)
    end

    it 'sets up the Hyacinth client' do
      expect(instance.instance_variable_get(:@client)).to eq(hyacinth_client)
    end

    it 'initializes syncing_errors as empty array' do
      expect(instance.syncing_errors).to eq([])
    end
  end

  describe '#sync' do
    let(:folio_to_hyacinth_record) { instance_double(FolioToHyacinthRecord, digital_object_data: { 'title' => 'Test' }) }

    before do
      allow(FolioToHyacinthRecord).to receive(:new).and_return(folio_to_hyacinth_record)
    end

    context 'when no existing records are found' do
      let(:existing_records) { [] }

      before do
        allow(hyacinth_client).to receive(:create_new_record).and_return({ 'success' => true })
      end

      it 'creates a new record' do
        expect(hyacinth_client).to receive(:create_new_record).with(
          folio_to_hyacinth_record.digital_object_data,
          publish: true
        )
        instance.sync(marc_file_path, folio_hrid, existing_records)
      end

      it 'creates a FolioToHyacinthRecord with the marc file path' do
        expect(FolioToHyacinthRecord).to receive(:new).with(marc_file_path)
        instance.sync(marc_file_path, folio_hrid, existing_records)
      end

      it 'logs the creation' do
        expect(logger).to receive(:info).with(/Creating new Hyacinth record for #{folio_hrid}/)
        expect(logger).to receive(:info).with(/Created record for #{folio_hrid}/)
        instance.sync(marc_file_path, folio_hrid, existing_records)
      end

      it 'does not add errors to syncing_errors' do
        instance.sync(marc_file_path, folio_hrid, existing_records)
        expect(instance.syncing_errors).to eq([])
      end
    end

    context 'when exactly one existing record is found' do
      let(:existing_pid) { 'abc123' }
      let(:existing_identifiers) { ['clio12345678', 'doi:10.1234/test'] }
      let(:existing_records) do
        [
          {
            'pid' => existing_pid,
            'identifiers' => existing_identifiers
          }
        ]
      end

      before do
        allow(hyacinth_client).to receive(:update_existing_record).and_return({ 'success' => true })
      end

      it 'updates the existing record' do
        expect(hyacinth_client).to receive(:update_existing_record).with(
          existing_pid,
          folio_to_hyacinth_record.digital_object_data,
          publish: true
        )
        instance.sync(marc_file_path, folio_hrid, existing_records)
      end

      it 'creates a FolioToHyacinthRecord with preserved identifiers' do
        expect(FolioToHyacinthRecord).to receive(:new).with(
          marc_file_path,
          { 'identifiers' => existing_identifiers }
        )
        instance.sync(marc_file_path, folio_hrid, existing_records)
      end

      it 'logs the update' do
        expect(logger).to receive(:info).with("Updating existing Hyacinth record for #{folio_hrid}")
        expect(logger).to receive(:info).with(/Updated record #{existing_pid}/)
        instance.sync(marc_file_path, folio_hrid, existing_records)
      end

      it 'does not add errors to syncing_errors' do
        instance.sync(marc_file_path, folio_hrid, existing_records)
        expect(instance.syncing_errors).to eq([])
      end
    end

    context 'when multiple existing records are found' do
      let(:existing_records) do
        [
          { 'pid' => 'abc123' },
          { 'pid' => 'def456' }
        ]
      end

      it 'does not attempt to create or update records' do
        expect(hyacinth_client).not_to receive(:create_new_record)
        expect(hyacinth_client).not_to receive(:update_existing_record)
        instance.sync(marc_file_path, folio_hrid, existing_records)
      end

      it 'logs an error' do
        expect(logger).to receive(:error).with("Multiple Hyacinth records found for FOLIO HRID #{folio_hrid}")
        instance.sync(marc_file_path, folio_hrid, existing_records)
      end

      it 'adds error to syncing_errors' do
        instance.sync(marc_file_path, folio_hrid, existing_records)
        expect(instance.syncing_errors).to include("Multiple Hyacinth records found for FOLIO HRID #{folio_hrid}")
      end
    end

    context 'when creating a new record fails' do
      let(:existing_records) { [] }
      let(:error_message) { 'API connection refused' }

      before do
        allow(hyacinth_client).to receive(:create_new_record).and_raise(StandardError.new(error_message))
      end

      it 'logs the error' do
        expect(logger).to receive(:error).with("Failed to create record for #{folio_hrid}: #{error_message}")
        instance.sync(marc_file_path, folio_hrid, existing_records)
      end

      it 'adds error to syncing_errors' do
        instance.sync(marc_file_path, folio_hrid, existing_records)
        expect(instance.syncing_errors).to include("Failed to create record for #{folio_hrid}: #{error_message}")
      end
    end

    context 'when updating an existing record fails' do
      let(:existing_pid) { 'abc123' }
      let(:existing_records) do
        [
          {
            'pid' => existing_pid,
            'identifiers' => ['clio12345678']
          }
        ]
      end
      let(:error_message) { 'Couldn\'t update record due to API error' }

      before do
        allow(hyacinth_client).to receive(:update_existing_record).and_raise(StandardError.new(error_message))
      end

      it 'logs the error' do
        expect(logger).to receive(:error).with("Failed to update record #{existing_pid} for #{folio_hrid}: #{error_message}")
        instance.sync(marc_file_path, folio_hrid, existing_records)
      end

      it 'adds error to syncing_errors' do
        instance.sync(marc_file_path, folio_hrid, existing_records)
        expect(instance.syncing_errors).to include("Failed to update record #{existing_pid} for #{folio_hrid}: #{error_message}")
      end
    end
  end
end
