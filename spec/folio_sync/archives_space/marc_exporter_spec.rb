# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FolioSync::ArchivesSpace::MarcExporter do
  let(:instance) { described_class.new }
  let(:client) { instance_double(FolioSync::ArchivesSpace::Client) }
  let(:logger) { instance_double(Logger, info: nil) }

  before do
    allow(FolioSync::ArchivesSpace::Client).to receive(:instance).and_return(client)
    allow(Logger).to receive(:new).and_return(logger)
  end

  describe '#initialize' do
    it 'can be instantiated' do
      expect(instance).to be_a(described_class)
    end

    it 'initializes with the ArchivesSpace client' do
      synchronizer = described_class.new
      expect(synchronizer.instance_variable_get(:@client)).to eq(client)
    end

    it 'initializes with a logger' do
      expect(instance.instance_variable_get(:@logger)).to eq(logger)
    end
  end

  describe '#export_recent_resources' do
    let(:repositories) do
      [
        { 'uri' => '/repositories/1', 'publish' => true },
        { 'uri' => '/repositories/2', 'publish' => false }
      ]
    end
    let(:modified_since) { Time.utc(2023, 1, 1) }

    before do
      allow(client).to receive(:get_all_repositories).and_return(repositories)
      allow(instance).to receive(:log_repository_skip)
      allow(instance).to receive(:export_resources_from_repository)
    end

    it 'fetches all repositories from the ArchivesSpace client' do
      instance.export_recent_resources(modified_since)
      expect(client).to have_received(:get_all_repositories)
    end

    it 'processes published repositories' do
      instance.export_recent_resources(modified_since)
      expect(instance).to have_received(:export_resources_from_repository).with('1', modified_since)
    end

    it 'skips unpublished repositories' do
      instance.export_recent_resources(modified_since)
      expect(instance).to have_received(:log_repository_skip).with(repositories[1])
    end
  end

  describe '#export_resources_from_repository' do
    let(:repo_id) { '1' }
    let(:resources) { [{ 'uri' => '/resources/1', 'title' => 'Resource 1', 'id' => '1', 'identifier' => '123' }] }
    let(:query_params) { { q: 'test_query', page: 1, page_size: 20 } }
    let(:modified_since) { Time.utc(2023, 1, 1) }

    before do
      allow(instance).to receive(:build_query_params).and_return(query_params)
      allow(client).to receive(:retrieve_paginated_resources).and_yield(resources)
      allow(instance).to receive(:log_resource_processing)
      allow(instance).to receive(:export_marc_for_resource)
    end

    it 'builds query parameters with the provided modified_since timestamp' do
      allow(Time).to receive(:now).and_return(Time.utc(2025, 4, 1, 12, 0, 0, 123_939))
      modified_since = Time.now.utc - FolioSync::ArchivesSpaceToFolio::FolioSynchronizer::ONE_DAY_IN_SECONDS
      instance.send(:export_resources_from_repository, repo_id, modified_since)
      expect(instance).to have_received(:build_query_params).with(modified_since)
    end

    it 'retrieves paginated resources from the ArchivesSpace client' do
      instance.send(:export_resources_from_repository, repo_id, modified_since)
      expect(client).to have_received(:retrieve_paginated_resources).with(repo_id, query_params)
    end

    it 'logs each resource being processed' do
      instance.send(:export_resources_from_repository, repo_id, modified_since)
      expect(instance).to have_received(:log_resource_processing).with(resources[0])
    end

    it 'fetches and saves MARC data for each resource' do
      instance.send(:export_resources_from_repository, repo_id, modified_since)
      expect(instance).to have_received(:export_marc_for_resource).with(repo_id, '1', '123')
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

  describe '#export_marc_for_resource' do
    let(:repo_id) { '1' }
    let(:resource_id) { '123' }
    let(:bib_id) { '456' }
    let(:marc_data) { '<record><controlfield tag="001">123456</controlfield></record>' }
    let(:file_path) { Rails.root.join("tmp/marc_files/#{bib_id}.xml") }

    before do
      allow(client).to receive(:fetch_marc_xml_resource).with(repo_id, resource_id).and_return(marc_data)
      allow(File).to receive(:binwrite)
    end

    it 'fetches MARC data from the ArchivesSpace client' do
      instance.send(:export_marc_for_resource, repo_id, resource_id, bib_id)
      expect(client).to have_received(:fetch_marc_xml_resource).with(repo_id, resource_id)
    end

    it 'saves MARC data to a local file' do
      instance.send(:export_marc_for_resource, repo_id, resource_id, bib_id)
      expect(File).to have_received(:binwrite).with(file_path, marc_data)
    end

    it 'does not save if MARC data is nil' do
      allow(client).to receive(:fetch_marc_xml_resource).and_return(nil)
      expect(logger).to receive(:error).with("No MARC found for repo #{repo_id} and resource_id #{resource_id}")
      instance.send(:export_marc_for_resource, repo_id, resource_id, bib_id)
      expect(File).not_to have_received(:binwrite)
    end
  end
end
