# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FolioSync::ArchivesSpaceToFolio::FolioSynchronizer do
  include_context 'FolioSync directory setup'

  let(:instance_key) { 'instance1' }
  let(:instance) { described_class.new(instance_key) }
  let(:last_x_hours) { 4 }
  let(:aspace_client) { instance_double(FolioSync::ArchivesSpace::Client) }
  let(:folio_writer) { instance_double(FolioSync::Folio::Writer) }
  let(:logger) { instance_double(Logger, info: nil, error: nil, debug: nil) }
  let(:archivesspace_config) do
    {
      'instance1' => {
        base_url: 'https://example1-test.library.edu/api',
        username: 'test-user',
        password: 'test-password',
        timeout: 60
      }
    }
  end
  let(:records) do
    [
      instance_double(AspaceToFolioRecord, archivesspace_marc_xml_path: 'instance1/repo1-resource1-aspace.xml',
                                          folio_marc_xml_path: 'instance1/repo1-resource1-folio.xml',
                                          folio_hrid: 'hrid1',
                                          repository_key: 1,
                                          resource_key: 123),
      instance_double(AspaceToFolioRecord, archivesspace_marc_xml_path: 'instance1/repo2-resource2-aspace.xml',
                                          folio_marc_xml_path: nil,
                                          folio_hrid: nil,
                                          repository_key: 2,
                                          resource_key: 456)
    ]
  end

  let(:relation_double) { double('ActiveRecord::Relation') }

  before do
    allow(Rails.configuration).to receive_messages(archivesspace: archivesspace_config)
    allow(Logger).to receive(:new).and_return(logger)
    allow(AspaceToFolioRecord).to receive(:where)
      .with(archivesspace_instance_key: instance_key, pending_update: 'to_folio')
      .and_return(relation_double)

    # Stub in_batches to yield the array as a single batch
    allow(relation_double).to receive(:empty?).and_return(records.empty?)
    allow(relation_double).to receive(:in_batches).and_yield(records)

    # Mock ArchivesSpace client dependencies
    allow(ArchivesSpace::Configuration).to receive(:new).and_return(double('config'))
    allow_any_instance_of(FolioSync::ArchivesSpace::Client).to receive(:login)

    allow(File).to receive(:join).and_return('/mocked/path/to/file.xml')
    allow(File).to receive(:binwrite) # Mock file writing
  end

  describe '#initialize' do
    it 'can be instantiated' do
      expect(instance).to be_a(described_class)
    end

    it 'initializes with a logger' do
      expect(instance.instance_variable_get(:@logger)).to eq(logger)
    end

    it 'stores the instance key' do
      expect(instance.instance_variable_get(:@instance_key)).to eq(instance_key)
    end

    it 'initializes downloading_errors and syncing_errors as empty arrays' do
      expect(instance.downloading_errors).to eq([])
      expect(instance.syncing_errors).to eq([])
    end
  end

  # describe '#fetch_and_sync_resources_to_folio' do
  #   let(:current_time) { Time.utc(2025, 5, 11, 15, 25, 23, 516_125) }
  #   let(:modified_since) { current_time - (last_x_hours * described_class::ONE_HOUR_IN_SECONDS) }

  #   before do
  #     allow(Time).to receive(:now).and_return(current_time)
  #     allow(instance).to receive(:download_archivesspace_marc_xml)
  #     allow(instance).to receive(:sync_resources_to_folio)
  #   end

  #   it 'fetches and saves recent MARC resources' do
  #     instance.fetch_and_sync_resources_to_folio(last_x_hours)
  #     expect(instance).to have_received(:download_archivesspace_marc_xml).with(modified_since)
  #   end

  #   it 'syncs resources to FOLIO' do
  #     instance.fetch_and_sync_resources_to_folio(last_x_hours)
  #     expect(instance).to have_received(:sync_resources_to_folio)
  #   end

  #   it 'handles nil last_x_hours to fetch all resources' do
  #     instance.fetch_and_sync_resources_to_folio(nil)
  #     expect(instance).to have_received(:download_archivesspace_marc_xml).with(nil)
  #   end
  # end

  # describe '#download_archivesspace_marc_xml' do
  #   let(:modified_since) { Time.utc(2023, 1, 1) }
  #   let(:exporter) { instance_double(FolioSync::ArchivesSpace::MarcExporter) }
  #   let(:exporting_errors) do
  #     [
  #       FolioSync::Errors::DownloadingError.new(
  #         resource_uri: 'repositories/1/resources/123',
  #         message: 'Error message 1'
  #       ),
  #       FolioSync::Errors::DownloadingError.new(
  #         resource_uri: 'repositories/2/resources/456',
  #         message: 'Error message 2'
  #       )
  #     ]
  #   end

  #   before do
  #     allow(FolioSync::ArchivesSpace::MarcExporter).to receive(:new).with(instance_key).and_return(exporter)
  #     allow(exporter).to receive(:export_recent_resources)
  #     allow(exporter).to receive(:exporting_errors).and_return(exporting_errors)
  #   end

  #   it 'initializes a MarcExporter and calls export_recent_resources with the correct modified_since' do
  #     instance.download_archivesspace_marc_xml(modified_since)
  #     expect(FolioSync::ArchivesSpace::MarcExporter).to have_received(:new).with(instance_key)
  #     expect(exporter).to have_received(:export_recent_resources).with(modified_since)
  #   end

  #   it 'logs errors if exporting_errors are present' do
  #     instance.download_archivesspace_marc_xml(modified_since)
  #     expect(logger).to have_received(:error).with("Errors encountered during MARC XML download: #{exporting_errors}")
  #   end

  #   it 'updates @downloading_errors with DownloadingError instances if present' do
  #     instance.download_archivesspace_marc_xml(modified_since)
  #     expect(instance.downloading_errors).to eq(exporting_errors)
  #   end

  #   it 'does not log errors or update @downloading_errors if exporting_errors is empty' do
  #     allow(exporter).to receive(:exporting_errors).and_return([])
  #     instance.download_archivesspace_marc_xml(modified_since)
  #     expect(logger).not_to have_received(:error)
  #     expect(instance.downloading_errors).to be_empty
  #   end

  #   it 'handles nil modified_since to fetch all resources' do
  #     instance.download_archivesspace_marc_xml(nil)
  #     expect(exporter).to have_received(:export_recent_resources).with(nil)
  #   end
  # end

  describe '#sync_resources_to_folio' do
    let(:batch_processor) { instance_double(FolioSync::ArchivesSpaceToFolio::BatchProcessor, process_records: nil, batch_errors: [], processing_errors: []) }
    let(:pending_records) { records }
    let(:relation_double) { double('ActiveRecord::Relation') }

    before do
      allow(AspaceToFolioRecord).to receive(:where)
        .with(archivesspace_instance_key: instance_key, pending_update: 'to_folio')
        .and_return(relation_double)
      allow(relation_double).to receive(:empty?).and_return(pending_records.empty?)
      allow(relation_double).to receive(:count).and_return(pending_records.count)
      allow(FolioSync::ArchivesSpaceToFolio::BatchProcessor).to receive(:new).with(instance_key).and_return(batch_processor)
    end

    context 'when there are no pending records' do
      let(:pending_records) { [] }

      before do
        allow(relation_double).to receive(:empty?).and_return(true)
        allow(relation_double).to receive(:count).and_return(0)
      end

      it 'logs that there are no pending records and returns' do
        instance.sync_resources_to_folio
        expect(logger).to have_received(:info).with("No pending records to sync for instance: #{instance_key}")
        expect(FolioSync::ArchivesSpaceToFolio::BatchProcessor).not_to have_received(:new)
      end
    end

    context 'when there are pending records' do
      let(:batch_errors) { [double('BatchError')] }
      let(:processing_errors) { [double('ProcessingError')] }

      before do
        allow(relation_double).to receive(:empty?).and_return(false)
        allow(batch_processor).to receive(:batch_errors).and_return(batch_errors)
        allow(batch_processor).to receive(:processing_errors).and_return(processing_errors)
      end

      it 'collects errors from the batch processor' do
        instance.sync_resources_to_folio
        expect(instance.syncing_errors).to include(*batch_errors, *processing_errors)
      end

      it 'logs an error if there are syncing errors' do
        instance.sync_resources_to_folio
        expect(logger).to have_received(:error).with("Errors encountered during sync: #{instance.syncing_errors.length} total errors")
      end
    end
  end
end
