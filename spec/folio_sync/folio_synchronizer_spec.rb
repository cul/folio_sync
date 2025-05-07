# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FolioSync::ArchivesSpaceToFolio::FolioSynchronizer do
  let(:instance) { described_class.new }
  let(:aspace_client) { instance_double(FolioSync::ArchivesSpace::Client) }
  let(:folio_client) { instance_double(FolioSync::Folio::Client) }
  let(:logger) { instance_double(Logger, info: nil) }

  before do
    allow(FolioSync::ArchivesSpace::Client).to receive(:instance).and_return(aspace_client)
    allow(FolioSync::Folio::Client).to receive(:instance).and_return(folio_client)
    allow(Logger).to receive(:new).and_return(logger)
  end

  describe '#initialize' do
    it 'can be instantiated' do
      expect(instance).to be_a(described_class)
    end

    it 'initializes with the ArchivesSpace client' do
      synchronizer = described_class.new
      expect(synchronizer.instance_variable_get(:@aspace_client)).to eq(aspace_client)
    end

    it 'initializes with the FOLIO client' do
      synchronizer = described_class.new
      expect(synchronizer.instance_variable_get(:@folio_client)).to eq(folio_client)
    end

    it 'initializes with a logger' do
      expect(instance.instance_variable_get(:@logger)).to eq(logger)
    end
  end

  describe '#fetch_and_sync_resources_to_folio' do
    before do
      allow(instance).to receive(:fetch_and_save_recent_marc_resources)
      allow(instance).to receive(:sync_resources_to_folio)
    end

    it 'fetches and saves recent MARC resources' do
      instance.fetch_and_sync_resources_to_folio
      expect(instance).to have_received(:fetch_and_save_recent_marc_resources)
    end

    it 'syncs resources to FOLIO' do
      instance.fetch_and_sync_resources_to_folio
      expect(instance).to have_received(:sync_resources_to_folio)
    end
  end

  describe '#fetch_and_save_recent_marc_resources' do
    let(:repositories) do
      [{ 'uri' => '/repositories/1', 'publish' => true }, { 'uri' => '/repositories/2', 'publish' => false }]
    end

    before do
      allow(aspace_client).to receive(:get_all_repositories).and_return(repositories)
      allow(instance).to receive(:fetch_resources_in_repo_since_time_and_save_locally)
      allow(instance).to receive(:log_repository_skip)
    end

    it 'fetches all repositories from the ArchivesSpace client' do
      instance.fetch_and_save_recent_marc_resources
      expect(aspace_client).to have_received(:get_all_repositories)
    end

    it 'processes published repositories with a modified_since timestamp' do
      allow(Time).to receive(:now).and_return(Time.utc(2025, 4, 1, 12, 0o0, 0o0, 123_939))
      modified_since = Time.now.utc - described_class::ONE_DAY_IN_SECONDS
      instance.fetch_and_save_recent_marc_resources
      expect(instance).to have_received(:fetch_resources_in_repo_since_time_and_save_locally).with('1',
                                                                                                   modified_since: modified_since)
    end

    it 'skips unpublished repositories' do
      instance.fetch_and_save_recent_marc_resources
      expect(instance).to have_received(:log_repository_skip).with(repositories[1])
    end
  end

  describe '#fetch_resources_in_repo_since_time_and_save_locally' do
    let(:repo_id) { '1' }
    let(:resources) { [{ 'uri' => '/resources/1', 'title' => 'Resource 1', 'id' => '1', 'identifier' => '123' }] }
    let(:query_params) { { q: 'test_query', page: 1, page_size: 20 } }

    before do
      allow(Time).to receive(:now).and_return(Time.utc(2023, 1, 1))
      allow(instance).to receive(:build_query_params).and_return(query_params)
      allow(aspace_client).to receive(:retrieve_paginated_resources).and_yield(resources)
      allow(instance).to receive(:log_resource_processing)
      allow(instance).to receive(:fetch_and_save_marc)
    end

    it 'builds query parameters with the provided modified_since timestamp' do
      allow(Time).to receive(:now).and_return(Time.utc(2025, 4, 1, 12, 0o0, 0o0, 123_939))
      modified_since = Time.now.utc - described_class::ONE_DAY_IN_SECONDS
      instance.send(:fetch_resources_in_repo_since_time_and_save_locally, repo_id, modified_since: modified_since)
      expect(instance).to have_received(:build_query_params).with(modified_since)
    end

    it 'retrieves paginated resources from the ArchivesSpace client' do
      instance.send(:fetch_resources_in_repo_since_time_and_save_locally, repo_id)
      expect(aspace_client).to have_received(:retrieve_paginated_resources).with(repo_id, query_params)
    end

    it 'logs each resource being processed' do
      instance.send(:fetch_resources_in_repo_since_time_and_save_locally, repo_id)
      expect(instance).to have_received(:log_resource_processing).with(resources[0])
    end

    it 'fetches and saves MARC data for each resource' do
      instance.send(:fetch_resources_in_repo_since_time_and_save_locally, repo_id)
      expect(instance).to have_received(:fetch_and_save_marc).with(repo_id, '1', '123')
    end
  end

  describe '#build_query_params' do
    let(:modified_since) { Time.utc(2023, 1, 1) }

    it 'builds query parameters with a modification time filter' do
      result = instance.send(:build_query_params, modified_since)
      expect(result).to eq({
        q: 'primary_type:resource suppressed:false system_mtime:[2023-01-01T00:00:00.000Z TO *]',
        page: 1,
        page_size: described_class::PAGE_SIZE,
        fields: %w[id identifier system_mtime title publish]
      })
    end

    it 'builds query parameters without a modification time filter when modified_since is nil' do
      result = instance.send(:build_query_params, nil)
      expect(result).to eq({
        q: 'primary_type:resource suppressed:false',
        page: 1,
        page_size: described_class::PAGE_SIZE,
        fields: %w[id identifier system_mtime title publish]
      })
    end
  end

  describe '#fetch_and_save_marc' do
    let(:repo_id) { '1' }
    let(:resource_id) { '123' }
    let(:bib_id) { '456' }
    let(:marc_data) { '<record><controlfield tag="001">123456</controlfield></record>' }
    let(:file_path) { Rails.root.join("tmp/marc_files/#{bib_id}.xml") }

    before do
      allow(aspace_client).to receive(:fetch_marc_data).with(repo_id, resource_id).and_return(marc_data)
      allow(File).to receive(:binwrite)
    end

    it 'fetches MARC data from the ArchivesSpace client' do
      instance.send(:fetch_and_save_marc, repo_id, resource_id, bib_id)
      expect(aspace_client).to have_received(:fetch_marc_data).with(repo_id, resource_id)
    end

    it 'saves MARC data to a local file' do
      instance.send(:fetch_and_save_marc, repo_id, resource_id, bib_id)
      expect(File).to have_received(:binwrite).with(file_path, marc_data)
    end

    it 'does not save if MARC data is nil' do
      allow(aspace_client).to receive(:fetch_marc_data).and_return(nil)
      instance.send(:fetch_and_save_marc, repo_id, resource_id, bib_id)
      expect(File).not_to have_received(:binwrite)
    end
  end

  describe '#sync_resources_to_folio' do
    let(:marc_dir) { Rails.root.join('tmp/marc_files') }
    let(:files) { ['file1.xml', 'file2.xml'] }
    let(:enhancers) { files.map { instance_double(FolioSync::ArchivesSpaceToFolio::MarcRecordEnhancer) } }
    let(:marc_records) { enhancers.map { double('MARC::Record') } }

    before do
      # Mock directory iteration
      allow(Dir).to receive(:foreach).with(marc_dir).and_yield('.').and_yield('..').and_yield(files[0]).and_yield(files[1])

      # Mock MarcRecordEnhancer behavior for each file
      files.each_with_index do |file, index|
        allow(FolioSync::ArchivesSpaceToFolio::MarcRecordEnhancer).to receive(:new).with(File.basename(file,
                                                                                                       '.xml')).and_return(enhancers[index])
        allow(enhancers[index]).to receive(:enhance!)
        allow(enhancers[index]).to receive(:marc_record).and_return(marc_records[index])
      end
      allow(folio_client).to receive(:create_or_update_folio_record)
    end

    it 'processes each MARC file in the directory' do
      instance.sync_resources_to_folio
      files.each_with_index do |file, index|
        bib_id = File.basename(file, '.xml')
        expect(FolioSync::ArchivesSpaceToFolio::MarcRecordEnhancer).to have_received(:new).with(bib_id)
        expect(enhancers[index]).to have_received(:enhance!)
        expect(folio_client).to have_received(:create_or_update_folio_record).with(marc_records[index])
      end
    end

    it 'skips "." and ".." entries' do
      instance.sync_resources_to_folio
      expect(FolioSync::ArchivesSpaceToFolio::MarcRecordEnhancer).not_to have_received(:new).with('.')
      expect(FolioSync::ArchivesSpaceToFolio::MarcRecordEnhancer).not_to have_received(:new).with('..')
    end
  end
end
