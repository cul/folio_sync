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
  let(:enhancers) { records.map { instance_double(FolioSync::ArchivesSpaceToFolio::MarcRecordEnhancer) } }
  let(:marc_records) { enhancers.map { double('MARC::Record') } }


  before do
    allow(Rails.configuration).to receive_messages(archivesspace: archivesspace_config)
    allow(Logger).to receive(:new).and_return(logger)
        allow(AspaceToFolioRecord).to receive(:where).with(archivesspace_instance_key: instance_key, pending_update: 'to_folio').and_return(records)

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

  describe '#fetch_and_sync_resources_to_folio' do
    let(:current_time) { Time.utc(2025, 5, 11, 15, 25, 23, 516_125) }
    let(:modified_since) { current_time - (last_x_hours * described_class::ONE_HOUR_IN_SECONDS) }

    before do
      allow(Time).to receive(:now).and_return(current_time)
      allow(instance).to receive(:download_archivesspace_marc_xml)
      allow(instance).to receive(:sync_resources_to_folio)
    end

    it 'fetches and saves recent MARC resources' do
      instance.fetch_and_sync_resources_to_folio(last_x_hours)
      expect(instance).to have_received(:download_archivesspace_marc_xml).with(modified_since)
    end

    it 'syncs resources to FOLIO' do
      instance.fetch_and_sync_resources_to_folio(last_x_hours)
      expect(instance).to have_received(:sync_resources_to_folio)
    end

    it 'handles nil last_x_hours to fetch all resources' do
      instance.fetch_and_sync_resources_to_folio(nil)
      expect(instance).to have_received(:download_archivesspace_marc_xml).with(nil)
    end
  end

  describe '#download_archivesspace_marc_xml' do
    let(:modified_since) { Time.utc(2023, 1, 1) }
    let(:exporter) { instance_double(FolioSync::ArchivesSpace::MarcExporter) }
    let(:exporting_errors) do
      [
        FolioSync::Errors::DownloadingError.new(
          resource_uri: 'repositories/1/resources/123',
          message: 'Error message 1'
        ),
        FolioSync::Errors::DownloadingError.new(
          resource_uri: 'repositories/2/resources/456',
          message: 'Error message 2'
        )
      ]
    end

    before do
      allow(FolioSync::ArchivesSpace::MarcExporter).to receive(:new).with(instance_key).and_return(exporter)
      allow(exporter).to receive(:export_recent_resources)
      allow(exporter).to receive(:exporting_errors).and_return(exporting_errors)
    end

    it 'initializes a MarcExporter and calls export_recent_resources with the correct modified_since' do
      instance.download_archivesspace_marc_xml(modified_since)
      expect(FolioSync::ArchivesSpace::MarcExporter).to have_received(:new).with(instance_key)
      expect(exporter).to have_received(:export_recent_resources).with(modified_since)
    end

    it 'logs errors if exporting_errors are present' do
      instance.download_archivesspace_marc_xml(modified_since)
      expect(logger).to have_received(:error).with("Errors encountered during MARC XML download: #{exporting_errors}")
    end

    it 'updates @downloading_errors with DownloadingError instances if present' do
      instance.download_archivesspace_marc_xml(modified_since)
      expect(instance.downloading_errors).to eq(exporting_errors)
    end

    it 'does not log errors or update @downloading_errors if exporting_errors is empty' do
      allow(exporter).to receive(:exporting_errors).and_return([])
      instance.download_archivesspace_marc_xml(modified_since)
      expect(logger).not_to have_received(:error)
      expect(instance.downloading_errors).to be_empty
    end

    it 'handles nil modified_since to fetch all resources' do
      instance.download_archivesspace_marc_xml(nil)
      expect(exporter).to have_received(:export_recent_resources).with(nil)
    end
  end

  describe '#sync_resources_to_folio' do
    let(:base_dir) { Rails.configuration.folio_sync[:aspace_to_folio][:marc_download_base_directory] }
    let(:downloads_dir) { File.join(base_dir, instance_key) }
    let(:enhancers) { records.map { instance_double(FolioSync::ArchivesSpaceToFolio::MarcRecordEnhancer) } }
    let(:marc_records) { enhancers.map { double('MARC::Record') } }

    before do
      allow(FolioSync::ArchivesSpaceToFolio::MarcRecordEnhancer).to receive(:new).and_return(*enhancers)
      enhancers.each_with_index do |enhancer, index|
        allow(enhancer).to receive(:enhance_marc_record!).and_return(marc_records[index])
        allow(enhancer).to receive(:marc_record).and_return(marc_records[index])
      end
      allow(File).to receive(:join).and_return('/mocked/path/to/file.xml')
      allow(File).to receive(:binwrite)
    end

    it 'processes each database record and enhances MARC records' do
      instance.sync_resources_to_folio
      records.each_with_index do |record, index|
        expect(FolioSync::ArchivesSpaceToFolio::MarcRecordEnhancer).to have_received(:new).with(
          File.join(base_dir, record.archivesspace_marc_xml_path),
          record.folio_hrid ? File.join(base_dir, record.folio_marc_xml_path) : nil,
          record.folio_hrid,
          instance_key
        )
        expect(enhancers[index]).to have_received(:enhance_marc_record!)
      end
    end

    it 'appends SyncingError instances to @syncing_errors when errors occur' do
      allow(enhancers[0]).to receive(:enhance_marc_record!).and_raise(StandardError, 'Enhancer error')
      instance.sync_resources_to_folio
      expect(logger).to have_received(:error).with('Error syncing resources to FOLIO: Enhancer error').at_least(:once)
      expect(instance.syncing_errors).to include(
        an_instance_of(FolioSync::Errors::SyncingError).and(
          have_attributes(
            resource_uri: 'repositories/1/resources/123',
            message: 'Enhancer error'
          )
        )
      )
    end
  end

  describe '#update_archivesspace_records' do
    let(:pending_records) do
      [
        instance_double(
          AspaceToFolioRecord,
          repository_key: 1,
          resource_key: 123,
          folio_hrid: 'hrid1',
        ),
        instance_double(
          AspaceToFolioRecord,
          repository_key: 2,
          resource_key: 456,
          folio_hrid: 'hrid2',
        )
      ]
    end
    let(:updater) { instance_double(FolioSync::ArchivesSpace::ResourceUpdater, updating_errors: []) }

    before do
      allow(AspaceToFolioRecord).to receive(:where).with(
        archivesspace_instance_key: instance_key,
        pending_update: 'to_aspace'
      ).and_return(pending_records)
      allow(FolioSync::ArchivesSpace::ResourceUpdater).to receive(:new).with(instance_key).and_return(updater)
      allow(updater).to receive(:update_records)
    end

    it 'instantiates ResourceUpdater and calls update_records with pending records' do
      instance.update_archivesspace_records
      expect(FolioSync::ArchivesSpace::ResourceUpdater).to have_received(:new).with(instance_key)
      expect(updater).to have_received(:update_records).with(pending_records)
    end

    it 'logs errors if updating_errors are present' do
      errors = [
        FolioSync::Errors::SyncingError.new(resource_uri: 'repositories/1/resources/123', message: 'Update failed')
      ]
      allow(updater).to receive(:updating_errors).and_return(errors)
      instance.update_archivesspace_records
      expect(logger).to have_received(:error).with("Errors encountered during ArchivesSpace updates: #{errors}")
    end
  end
end