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
      FactoryBot.create(:aspace_to_folio_record, :with_folio_data, archivesspace_instance_key: 'test_instance'),
      FactoryBot.create(:aspace_to_folio_record, folio_hrid: nil, archivesspace_instance_key: 'test_instance')
    ]
  end

  let(:relation_double) { double('ActiveRecord::Relation') }

  before do
    allow(Rails.configuration).to receive_messages(archivesspace: archivesspace_config)
    allow(Logger).to receive(:new).and_return(logger)

    # Stub for sync_prepared_marc_records_to_folio method
    allow(AspaceToFolioRecord).to receive(:where)
      .with(archivesspace_instance_key: instance_key, pending_update: 'to_folio')
      .and_return(relation_double)

    # Stub for update_archivesspace_records method
    allow(AspaceToFolioRecord).to receive(:where)
      .with(archivesspace_instance_key: instance_key, pending_update: 'to_aspace')
      .and_return([])

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

    it 'initializes error arrays as empty' do
      expect(instance.downloading_errors).to eq([])
      expect(instance.syncing_errors).to eq([])
      expect(instance.saving_errors).to eq([])
      expect(instance.fetching_errors).to eq([])
      expect(instance.linking_errors).to eq([])
    end
  end

  describe '#fetch_and_sync_aspace_to_folio_records' do
    let(:current_time) { Time.utc(2025, 5, 11, 15, 25, 23, 516_125) }
    let(:modified_since) { current_time - (last_x_hours * described_class::ONE_HOUR_IN_SECONDS) }

    before do
      allow(Time).to receive(:now).and_return(current_time)
      allow(instance).to receive(:fetch_archivesspace_resources)
      allow(instance).to receive(:download_marc_from_archivesspace_and_folio)
      allow(instance).to receive(:sync_prepared_marc_records_to_folio)
      allow(instance).to receive(:update_archivesspace_records)
      allow(instance).to receive(:database_valid?).and_return(true)
    end

    it 'fetches recent MARC resources from ArchivesSpace' do
      instance.fetch_and_sync_aspace_to_folio_records(last_x_hours)
      expect(instance).to have_received(:fetch_archivesspace_resources).with(modified_since)
    end

    it 'downloads MARC XML from ArchivesSpace and FOLIO' do
      instance.fetch_and_sync_aspace_to_folio_records(last_x_hours)
      expect(instance).to have_received(:download_marc_from_archivesspace_and_folio)
    end

    it 'syncs resources to FOLIO' do
      instance.fetch_and_sync_aspace_to_folio_records(last_x_hours)
      expect(instance).to have_received(:sync_prepared_marc_records_to_folio)
    end

    it 'handles nil last_x_hours to fetch all resources' do
      instance.fetch_and_sync_aspace_to_folio_records(nil)
      expect(instance).to have_received(:fetch_archivesspace_resources).with(nil)
    end

    it 'syncs resources to ArchivesSpace' do
      instance.fetch_and_sync_aspace_to_folio_records(last_x_hours)
      expect(instance).to have_received(:update_archivesspace_records)
    end
  end

  describe '#fetch_archivesspace_resources' do
    let(:fetcher) { instance_double(FolioSync::ArchivesSpace::ResourceFetcher, fetching_errors: [], saving_errors: []) }

    before do
      allow(FolioSync::ArchivesSpace::ResourceFetcher).to receive(:new).and_return(fetcher)
      allow(fetcher).to receive(:fetch_and_save_recent_resources)
    end

    it 'calls fetch_and_save_recent_resources on the fetcher' do
      instance.fetch_archivesspace_resources(nil)
      expect(fetcher).to have_received(:fetch_and_save_recent_resources).with(nil)
    end

    it 'sets fetching_errors and logs if present' do
      allow(fetcher).to receive(:fetching_errors).and_return(['fetch error'])
      expect(logger).to receive(:error).with(/Error fetching resources/)
      instance.fetch_archivesspace_resources(nil)
      expect(instance.fetching_errors).to eq(['fetch error'])
    end

    it 'sets saving_errors and logs if present' do
      allow(fetcher).to receive(:saving_errors).and_return(['save error'])
      expect(logger).to receive(:error).with(/Error saving resources/)
      instance.fetch_archivesspace_resources(nil)
      expect(instance.saving_errors).to eq(['save error'])
    end
  end

  describe '#download_marc_from_archivesspace_and_folio' do
    let(:downloader) { instance_double(FolioSync::ArchivesSpaceToFolio::MarcDownloader, downloading_errors: []) }

    before do
      allow(FolioSync::ArchivesSpaceToFolio::MarcDownloader).to receive(:new).and_return(downloader)
      allow(downloader).to receive(:download_pending_marc_records)
    end

    it 'calls download_pending_marc_records on the downloader' do
      instance.download_marc_from_archivesspace_and_folio
      expect(downloader).to have_received(:download_pending_marc_records)
    end

    it 'sets downloading_errors and logs if present' do
      allow(downloader).to receive(:downloading_errors).and_return(['download error'])
      expect(logger).to receive(:error).with(/Errors encountered during MARC download/)
      instance.download_marc_from_archivesspace_and_folio
      expect(instance.downloading_errors).to eq(['download error'])
    end
  end

  describe '#sync_prepared_marc_records_to_folio' do
    let(:pending_records) { records }
    let(:batch_processor) { instance_double(FolioSync::ArchivesSpaceToFolio::BatchProcessor, process_records: nil, syncing_errors: []) }

    before do
      allow(AspaceToFolioRecord).to receive(:where).and_return(pending_records)
      allow(FolioSync::ArchivesSpaceToFolio::BatchProcessor).to receive(:new).and_return(batch_processor)
    end

    context 'when there are no pending records' do
      before do
        allow(pending_records).to receive(:empty?).and_return(true)
      end

      it 'logs that there are no pending records and returns' do
        expect(logger).to receive(:info).with(/No pending records/)
        instance.sync_prepared_marc_records_to_folio
        expect(FolioSync::ArchivesSpaceToFolio::BatchProcessor).not_to have_received(:new)
      end
    end

    context 'when there are pending records' do
      before do
        allow(pending_records).to receive(:empty?).and_return(false)
        allow(pending_records).to receive(:count).and_return(2)
        allow(batch_processor).to receive(:syncing_errors).and_return(['syncing error'])
      end

      it 'processes records and collects errors' do
        expect(logger).to receive(:info).with(/Found 2 pending records/)
        expect(logger).to receive(:error).with(/Errors encountered during sync/)
        instance.sync_prepared_marc_records_to_folio
        expect(instance.syncing_errors).to include('syncing error')
      end
    end
  end

  describe '#clear_downloads!' do
    let(:config) { { marc_download_base_directory: '/tmp/downloads' } }

    before do
      allow(Rails).to receive_message_chain(:configuration, :folio_sync, :[]).with(:aspace_to_folio).and_return(config)
      allow(File).to receive(:join).and_call_original
      allow(FileUtils).to receive(:rm_rf)
      allow(Dir).to receive(:[]).and_return(['/tmp/downloads/instance1/file1.xml'])
    end

    it 'removes files in the downloads directory' do
      expect(FileUtils).to receive(:rm_rf).with(['/tmp/downloads/instance1/file1.xml'])
      instance.clear_downloads!
    end
  end

  describe '#update_archivesspace_records' do
    let(:pending_records) do
      [
        FactoryBot.create(:aspace_to_folio_record, :ready_for_aspace),
        FactoryBot.create(:aspace_to_folio_record, :ready_for_aspace)
      ]
    end
    let(:updater) { instance_double(FolioSync::ArchivesSpace::ResourceUpdater, updating_errors: []) }

    before do
      allow(AspaceToFolioRecord).to receive(:where)
        .with(archivesspace_instance_key: instance_key, pending_update: 'to_aspace')
        .and_return(pending_records)
      allow(FolioSync::ArchivesSpace::ResourceUpdater).to receive(:new).with(instance_key).and_return(updater)
      allow(updater).to receive(:update_single_record).and_return(true)
      pending_records.each do |record|
        allow(record).to receive(:update!).with(pending_update: 'no_update')
      end
    end

    it 'calls update_single_record for each pending record' do
      instance.update_archivesspace_records
      pending_records.each do |pending_record|
        expect(updater).to have_received(:update_single_record).with(pending_record)
      end
    end

    it 'updates the database record if ArchivesSpace resource is successfully updated' do
      pending_records.each do |pending_record|
        expect(pending_record).to receive(:update!).with(pending_update: 'no_update')
      end

      instance.update_archivesspace_records
    end

    it 'logs errors if updating_errors are present' do
      errors = [
        FolioSync::Errors::SyncingError.new(resource_uri: 'repositories/1/resources/123', message: 'Update failed'),
        FolioSync::Errors::SyncingError.new(resource_uri: 'repositories/2/resources/456', message: 'Update failed')
      ]
      allow(updater).to receive(:updating_errors).and_return(errors)
      allow(logger).to receive(:error)
      instance.update_archivesspace_records
      expect(logger).to have_received(:error).with("Errors encountered during ArchivesSpace updates: #{errors}")
    end
  end

  describe '#database_valid?' do
    let(:folio_sync_config) do
      {
        aspace_to_folio: {
          developer_email_address: 'developer@example.com'
        }
      }
    end
    let(:mailer_double) { double('ApplicationMailer', deliver: true) }

    before do
      allow(Rails).to receive_message_chain(:configuration, :folio_sync).and_return(folio_sync_config)
      allow(ApplicationMailer).to receive(:with).and_return(mailer_double)
      allow(mailer_double).to receive(:folio_sync_database_error_email).and_return(mailer_double)
    end

    context 'when database is valid' do
      before do
        # Create records with folio_hrid values (valid records) for the target instance
        FactoryBot.create(:aspace_to_folio_record, :with_folio_data, archivesspace_instance_key: instance_key)
        FactoryBot.create(:aspace_to_folio_record, :with_folio_data, archivesspace_instance_key: instance_key)

        # Create records for different instance (should not affect validation)
        FactoryBot.create(:aspace_to_folio_record, folio_hrid: nil, archivesspace_instance_key: 'other_instance')
      end

      it 'returns true' do
        expect(instance.database_valid?).to be true
      end

      it 'does not send email' do
        instance.database_valid?
        expect(ApplicationMailer).not_to have_received(:with)
      end

      it 'does not raise error' do
        expect { instance.database_valid? }.not_to raise_error
      end
    end

    context 'when database is invalid' do
      before do
        # Create a mix of valid and invalid records for the target instance
        FactoryBot.create(:aspace_to_folio_record, :with_folio_data, archivesspace_instance_key: instance_key)
        FactoryBot.create(:aspace_to_folio_record, folio_hrid: nil, archivesspace_instance_key: instance_key)

        # Create records for different instance (should not affect validation)
        FactoryBot.create(:aspace_to_folio_record, :with_folio_data, archivesspace_instance_key: 'other_instance')
      end

      it 'sends error email with correct parameters' do
        expect(ApplicationMailer).to receive(:with).with(
          to: 'developer@example.com',
          subject: "FOLIO Sync failed to validate database for #{instance_key}",
          instance_key: instance_key
        ).and_return(mailer_double)

        expect { instance.database_valid? }.to raise_error("Database is not valid for instance #{instance_key}.")
      end

      it 'raises error with correct message' do
        expect { instance.database_valid? }.to raise_error("Database is not valid for instance #{instance_key}.")
      end

      it 'does not return true' do
        expect { instance.database_valid? }.to raise_error(FolioSync::Exceptions::InvalidDatabaseState)
      end
    end
  end
end
