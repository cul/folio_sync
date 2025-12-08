# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FolioSync::FolioToHyacinth::HyacinthSynchronizer do
  let(:instance) { described_class.new }
  let(:logger) { instance_double(Logger, info: nil, error: nil, debug: nil) }
  let(:last_x_hours) { 24 }
  let(:folio_to_hyacinth_config) do
    {
      download_directory: '/tmp/folio_to_hyacinth/downloaded_files'
    }
  end

  before do
    allow(Logger).to receive(:new).and_return(logger)
    allow(Rails).to receive_message_chain(:configuration, :folio_to_hyacinth).and_return(folio_to_hyacinth_config)
  end

  describe '#initialize' do
    it 'can be instantiated' do
      expect(instance).to be_a(described_class)
    end

    it 'initializes with a logger' do
      expect(instance.instance_variable_get(:@logger)).to eq(logger)
    end

    it 'initializes error arrays as empty' do
      expect(instance.downloading_errors).to eq([])
      expect(instance.syncing_errors).to eq([])
    end
  end

  describe '#download_and_sync_folio_to_hyacinth_records' do
    before do
      allow(instance).to receive(:download_marc_from_folio)
      allow(instance).to receive(:prepare_and_sync_folio_to_hyacinth_records)
    end

    it 'downloads MARC from FOLIO' do
      instance.download_and_sync_folio_to_hyacinth_records(last_x_hours)
      expect(instance).to have_received(:download_marc_from_folio).with(last_x_hours)
    end

    it 'prepares and syncs records to Hyacinth' do
      instance.download_and_sync_folio_to_hyacinth_records(last_x_hours)
      expect(instance).to have_received(:prepare_and_sync_folio_to_hyacinth_records)
    end

    it 'handles nil last_x_hours to download all records' do
      instance.download_and_sync_folio_to_hyacinth_records(nil)
      expect(instance).to have_received(:download_marc_from_folio).with(nil)
    end
  end

  describe '#download_marc_from_folio' do
    let(:downloader) { instance_double(FolioSync::FolioToHyacinth::MarcDownloader, downloading_errors: []) }

    before do
      allow(FolioSync::FolioToHyacinth::MarcDownloader).to receive(:new).and_return(downloader)
      allow(downloader).to receive(:download_965hyacinth_marc_records)
    end

    it 'creates a new MarcDownloader instance' do
      expect(FolioSync::FolioToHyacinth::MarcDownloader).to receive(:new)
      instance.download_marc_from_folio(last_x_hours)
    end

    it 'calls download_965hyacinth_marc_records with correct parameter' do
      expect(downloader).to receive(:download_965hyacinth_marc_records).with(last_x_hours)
      instance.download_marc_from_folio(last_x_hours)
    end

    context 'when there are no downloading errors' do
      it 'does not set downloading_errors' do
        instance.download_marc_from_folio(last_x_hours)
        expect(instance.downloading_errors).to eq([])
      end

      it 'does not log errors' do
        instance.download_marc_from_folio(last_x_hours)
        expect(logger).not_to have_received(:error)
      end
    end

    context 'when there are downloading errors' do
      let(:errors) { ['Error downloading record 1', 'Error downloading record 2'] }

      before do
        allow(downloader).to receive(:downloading_errors).and_return(errors)
      end

      it 'sets downloading_errors' do
        instance.download_marc_from_folio(last_x_hours)
        expect(instance.downloading_errors).to eq(errors)
      end

      it 'logs the errors' do
        expect(logger).to receive(:error).with(/Error downloading MARC records from FOLIO/)
        instance.download_marc_from_folio(last_x_hours)
      end
    end
  end

  describe '#prepare_and_sync_folio_to_hyacinth_records' do
    let(:marc_files) { ['/tmp/downloads/record1.mrc', '/tmp/downloads/record2.mrc'] }

    before do
      allow(Dir).to receive(:glob).and_return(marc_files)
      allow(instance).to receive(:process_marc_file)
    end

    it 'finds MARC files in the download directory' do
      expect(Dir).to receive(:glob).with("#{folio_to_hyacinth_config[:download_directory]}/*.mrc")
      instance.prepare_and_sync_folio_to_hyacinth_records
    end

    it 'logs the number of files being processed' do
      expect(logger).to receive(:info).with("Processing #{marc_files.count} MARC files")
      instance.prepare_and_sync_folio_to_hyacinth_records
    end

    it 'processes each MARC file' do
      instance.prepare_and_sync_folio_to_hyacinth_records
      marc_files.each do |marc_file|
        expect(instance).to have_received(:process_marc_file).with(marc_file)
      end
    end

    context 'when there are no MARC files' do
      let(:marc_files) { [] }

      it 'does not process any files' do
        instance.prepare_and_sync_folio_to_hyacinth_records
        expect(instance).not_to have_received(:process_marc_file)
      end
    end
  end

  describe '#process_marc_file' do
    let(:marc_file_path) { '/tmp/downloads/record1.mrc' }
    let(:processor) { instance_double(FolioSync::FolioToHyacinth::MarcProcessor, syncing_errors: []) }

    before do
      allow(FolioSync::FolioToHyacinth::MarcProcessor).to receive(:new).and_return(processor)
      allow(processor).to receive(:prepare_and_sync_folio_to_hyacinth_record!)
    end

    it 'creates a new MarcProcessor with the file path' do
      expect(FolioSync::FolioToHyacinth::MarcProcessor).to receive(:new).with(marc_file_path)
      instance.send(:process_marc_file, marc_file_path)
    end

    it 'calls prepare_and_sync_folio_to_hyacinth_record!' do
      expect(processor).to receive(:prepare_and_sync_folio_to_hyacinth_record!)
      instance.send(:process_marc_file, marc_file_path)
    end

    context 'when there are no syncing errors' do
      it 'does not add to syncing_errors' do
        instance.send(:process_marc_file, marc_file_path)
        expect(instance.syncing_errors).to eq([])
      end
    end

    context 'when there are syncing errors' do
      let(:errors) { ['Error syncing record', 'Another error'] }

      before do
        allow(processor).to receive(:syncing_errors).and_return(errors)
      end

      it 'concatenates errors to syncing_errors' do
        instance.send(:process_marc_file, marc_file_path)
        expect(instance.syncing_errors).to eq(errors)
      end
    end

    context 'when processing multiple files with errors' do
      let(:processor2) { instance_double(FolioSync::FolioToHyacinth::MarcProcessor, syncing_errors: ['Error from file 2']) }
      let(:errors1) { ['Error from file 1'] }

      before do
        allow(processor).to receive(:syncing_errors).and_return(errors1)
        allow(FolioSync::FolioToHyacinth::MarcProcessor).to receive(:new)
          .with('/tmp/downloads/record2.mrc')
          .and_return(processor2)
        allow(processor2).to receive(:prepare_and_sync_folio_to_hyacinth_record!)
      end

      it 'accumulates errors from multiple processors' do
        instance.send(:process_marc_file, marc_file_path)
        instance.send(:process_marc_file, '/tmp/downloads/record2.mrc')
        expect(instance.syncing_errors).to eq(['Error from file 1', 'Error from file 2'])
      end
    end
  end

  describe '#clear_downloads!' do
    let(:download_path) { "#{folio_to_hyacinth_config[:download_directory]}/*.mrc" }

    before do
      allow(FileUtils).to receive(:rm_rf)
    end

    it 'removes files matching the download path pattern' do
      expect(FileUtils).to receive(:rm_rf).with(download_path)
      instance.clear_downloads!
    end
  end

  describe '#downloaded_marc_files_path' do
    it 'returns the correct glob pattern for MARC files' do
      expected_path = "#{folio_to_hyacinth_config[:download_directory]}/*.mrc"
      expect(instance.send(:downloaded_marc_files_path)).to eq(expected_path)
    end
  end
end