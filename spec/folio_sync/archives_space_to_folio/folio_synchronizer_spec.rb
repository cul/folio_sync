# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FolioSync::ArchivesSpaceToFolio::FolioSynchronizer do
  let(:instance) { described_class.new }
  let(:aspace_client) { instance_double(FolioSync::ArchivesSpace::Client) }
  let(:folio_writer) { instance_double(FolioSync::Folio::Writer) }
  let(:logger) { instance_double(Logger, info: nil) }

  before do
    allow(FolioSync::ArchivesSpace::Client).to receive(:instance).and_return(aspace_client)
    allow(Logger).to receive(:new).and_return(logger)
  end

  describe '#initialize' do
    it 'can be instantiated' do
      expect(instance).to be_a(described_class)
    end

    it 'initializes with a logger' do
      expect(instance.instance_variable_get(:@logger)).to eq(logger)
    end
  end

  describe '#fetch_and_sync_resources_to_folio' do
    let(:current_time) { Time.utc(2025, 5, 11, 15, 25, 23, 516_125) }
    let(:modified_since) { current_time - described_class::ONE_DAY_IN_SECONDS }

    before do
      allow(Time).to receive(:now).and_return(current_time)
      allow(instance).to receive(:download_archivesspace_marc_xml).with(modified_since)
      allow(instance).to receive(:sync_resources_to_folio)
    end

    it 'fetches and saves recent MARC resources' do
      instance.fetch_and_sync_resources_to_folio
      expect(instance).to have_received(:download_archivesspace_marc_xml).with(modified_since)
    end

    it 'syncs resources to FOLIO' do
      instance.fetch_and_sync_resources_to_folio
      expect(instance).to have_received(:sync_resources_to_folio)
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
      allow(FolioSync::ArchivesSpace::MarcExporter).to receive(:new).and_return(exporter)
      allow(exporter).to receive(:export_recent_resources)
      allow(exporter).to receive(:exporting_errors).and_return(exporting_errors)
      allow(logger).to receive(:error)
    end

    it 'initializes a MarcExporter and calls export_recent_resources with the correct modified_since' do
      instance.download_archivesspace_marc_xml(modified_since)
      expect(FolioSync::ArchivesSpace::MarcExporter).to have_received(:new)
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
    let(:marc_dir) { Rails.configuration.folio_sync['marc_download_directory'] }
    let(:files) { ['file1.xml', 'file2.xml'] }
    let(:enhancers) { files.map { instance_double(FolioSync::ArchivesSpaceToFolio::MarcRecordEnhancer) } }
    let(:marc_records) { enhancers.map { double('MARC::Record') } }

    before do
      allow(FolioSync::Folio::Writer).to receive(:new).and_return(folio_writer)

      # Mock directory iteration
      allow(Dir).to receive(:foreach).with(marc_dir).and_yield('.').and_yield('..').and_yield(files[0]).and_yield(files[1])

      # Mock MarcRecordEnhancer behavior for each file
      files.each_with_index do |file, index|
        allow(FolioSync::ArchivesSpaceToFolio::MarcRecordEnhancer).to receive(:new).with(File.basename(file,
                                                                                                       '.xml')).and_return(enhancers[index])
        allow(enhancers[index]).to receive(:enhance_marc_record!)
        allow(enhancers[index]).to receive(:marc_record).and_return(marc_records[index])
      end

      # Mock the folio_writer behavior
      allow(folio_writer).to receive(:create_or_update_folio_record)
    end

    it 'processes each MARC file in the directory' do
      instance.sync_resources_to_folio
      files.each_with_index do |file, index|
        bib_id = File.basename(file, '.xml')
        expect(FolioSync::ArchivesSpaceToFolio::MarcRecordEnhancer).to have_received(:new).with(bib_id)
        expect(enhancers[index]).to have_received(:enhance_marc_record!)
        expect(folio_writer).to have_received(:create_or_update_folio_record).with(marc_records[index])
      end
    end

    it 'skips "." and ".." entries' do
      instance.sync_resources_to_folio
      expect(FolioSync::ArchivesSpaceToFolio::MarcRecordEnhancer).not_to have_received(:new).with('.')
      expect(FolioSync::ArchivesSpaceToFolio::MarcRecordEnhancer).not_to have_received(:new).with('..')
    end

    it 'appends SyncingError instances to @syncing_errors when errors occur' do
      allow(enhancers[0]).to receive(:enhance_marc_record!).and_raise(StandardError, 'Enhancer error')
      expect(logger).to receive(:error).with('Error syncing resources to FOLIO: Enhancer error')
      instance.sync_resources_to_folio
      expect(instance.syncing_errors).to contain_exactly(
        an_instance_of(FolioSync::Errors::SyncingError).and(have_attributes(bib_id: 'file1', message: 'Enhancer error'))
      )
    end
  end
end
