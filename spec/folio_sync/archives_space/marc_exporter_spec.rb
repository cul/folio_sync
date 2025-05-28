# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FolioSync::ArchivesSpace::MarcExporter do
  include_context 'FolioSync directory setup'

  let(:instance_key) { 'instance1' }
  let(:client) { instance_double(FolioSync::ArchivesSpace::Client) }
  let(:logger) { instance_double(Logger, info: nil, error: nil) }

  before do
    allow(Logger).to receive(:new).and_return(logger)
    allow(FolioSync::ArchivesSpace::Client).to receive(:new).with(instance_key).and_return(client)
  end

  describe '#initialize' do
    it 'can be instantiated with an instance key' do
      instance = described_class.new(instance_key)
      expect(instance).to be_a(described_class)
    end

    it 'initializes with the ArchivesSpace client for the given instance' do
      instance = described_class.new(instance_key)
      expect(FolioSync::ArchivesSpace::Client).to have_received(:new).with(instance_key)
      expect(instance.instance_variable_get(:@client)).to eq(client)
    end

    it 'initializes with a logger' do
      instance = described_class.new(instance_key)
      expect(instance.instance_variable_get(:@logger)).to eq(logger)
    end

    it 'stores the instance directory' do
      instance = described_class.new(instance_key)
      expect(instance.instance_variable_get(:@instance_dir)).to eq(instance_key)
    end

    it 'initializes exporting_errors as an empty array' do
      instance = described_class.new(instance_key)
      expect(instance.exporting_errors).to eq([])
    end
  end

  describe '#export_recent_resources' do
    let(:instance) { described_class.new(instance_key) }
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
      allow(instance).to receive(:extract_id).and_return('1', '2')
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

    it 'extracts repository IDs from URIs' do
      instance.export_recent_resources(modified_since)
      expect(instance).to have_received(:extract_id).with('/repositories/1')
    end
  end

  describe '#export_resources_from_repository' do
    let(:instance) { described_class.new(instance_key) }
    let(:repo_id) { '1' }
    let(:resources) do
      [
        { 'uri' => '/resources/1', 'title' => 'Resource 1', 'id' => '1', 'identifier' => '123' },
        { 'uri' => '/resources/2', 'title' => 'Resource 2', 'id' => '2', 'identifier' => '456' }
      ]
    end
    let(:query_params) { { q: 'test_query', page: 1, page_size: 200 } }
    let(:modified_since) { Time.utc(2023, 1, 1) }

    before do
      allow(instance).to receive(:build_query_params).and_return(query_params)
      allow(client).to receive(:retrieve_paginated_resources).and_yield(resources)
      allow(instance).to receive(:log_resource_processing)
      allow(instance).to receive(:export_marc_for_resource)
      allow(instance).to receive(:extract_id).and_return('1', '2')
    end

    it 'builds query parameters with the provided modified_since timestamp' do
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
      expect(instance).to have_received(:log_resource_processing).with(resources[1])
    end

    it 'fetches and saves MARC data for each resource' do
      instance.send(:export_resources_from_repository, repo_id, modified_since)
      expect(instance).to have_received(:export_marc_for_resource).with(repo_id, '1', '123')
      expect(instance).to have_received(:export_marc_for_resource).with(repo_id, '2', '456')
    end

    it 'handles errors during resource processing' do
      error = StandardError.new('Test error')
      allow(instance).to receive(:export_marc_for_resource).and_raise(error)

      instance.send(:export_resources_from_repository, repo_id, modified_since)

      expect(logger).to have_received(:error).with("Error exporting MARC for resource 123 (repo_id: #{repo_id}): Test error")
      expect(instance.exporting_errors.length).to eq(2) # One for each resource
      expect(instance.exporting_errors.first).to be_a(FolioSync::Errors::DownloadingError)
      expect(instance.exporting_errors.first.resource_uri).to eq('/resources/1')
      expect(instance.exporting_errors.first.message).to eq('Test error')
    end
  end

  describe '#build_query_params' do
    let(:modified_since) { Time.utc(2023, 1, 1) }

    it 'builds query parameters with a modification time filter' do
      instance = described_class.new(instance_key)
      allow(instance).to receive(:time_to_solr_date_format).with(modified_since).and_return('2023-01-01T00:00:00.000Z')

      result = instance.send(:build_query_params, modified_since)

      expect(result).to eq({
        q: 'primary_type:resource suppressed:false system_mtime:[2023-01-01T00:00:00.000Z TO *]',
        page: 1,
        page_size: described_class::PAGE_SIZE,
        fields: %w[id identifier system_mtime title publish]
      })
    end

    it 'builds query parameters without a modification time filter when modified_since is nil' do
      instance = described_class.new(instance_key)
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
    let(:instance) { described_class.new(instance_key) }
    let(:repo_id) { '1' }
    let(:resource_id) { '123' }
    let(:bib_id) { '456' }
    let(:marc_data) { '<record><controlfield tag="001">123456</controlfield></record>' }
    let(:expected_file_path) { 'tmp/test/downloaded_files/instance1/456.xml' }

    before do
      allow(FolioSync::ArchivesSpace::Client).to receive(:new).with(instance_key).and_return(client)
      allow(client).to receive(:fetch_marc_xml_resource).with(repo_id, resource_id).and_return(marc_data)
      allow(File).to receive(:binwrite)
    end

    it 'fetches MARC data from the ArchivesSpace client' do
      instance.send(:export_marc_for_resource, repo_id, resource_id, bib_id)
      expect(client).to have_received(:fetch_marc_xml_resource).with(repo_id, resource_id)
    end

    it 'saves MARC data to a local file with correct path structure' do
      instance.send(:export_marc_for_resource, repo_id, resource_id, bib_id)
      expect(File).to have_received(:binwrite).with(expected_file_path, marc_data)
    end

    it 'raises an error if bib_id is nil' do
      expect {
        instance.send(:export_marc_for_resource, repo_id, resource_id, nil)
      }.to raise_error('No bib_id found')
    end

    it 'logs an error and returns early if MARC data is nil' do
      allow(client).to receive(:fetch_marc_xml_resource).and_return(nil)

      result = instance.send(:export_marc_for_resource, repo_id, resource_id, bib_id)

      expect(logger).to have_received(:error).with("No MARC found for repo #{repo_id} and resource_id #{resource_id}")
      expect(File).not_to have_received(:binwrite)
      expect(result).to be_nil
    end
  end

  describe '#time_to_solr_date_format' do
    it 'formats time correctly for Solr' do
      instance = described_class.new(instance_key)
      time = Time.utc(2023, 1, 1, 12, 30, 45, 123_000)
      result = instance.send(:time_to_solr_date_format, time)
      expect(result).to eq('2023-01-01T12:30:45.123Z')
    end
  end

  describe '#extract_id' do
    it 'extracts ID from URI' do
      instance = described_class.new(instance_key)
      uri = '/repositories/1/resources/123'
      result = instance.send(:extract_id, uri)
      expect(result).to eq('123')
    end
  end

  describe '#log_repository_skip' do
    let(:repo) { { 'uri' => '/repositories/1' } }

    it 'logs repository skip message' do
      instance = described_class.new(instance_key)
      instance.send(:log_repository_skip, repo)
      expect(logger).to have_received(:info).with('Repository /repositories/1 is not published, skipping...')
    end
  end

  describe '#log_resource_processing' do
    let(:resource) { { 'title' => 'Test Resource', 'id' => '123' } }

    it 'logs resource processing message' do
      instance = described_class.new(instance_key)
      instance.send(:log_resource_processing, resource)
      expect(logger).to have_received(:info).with('Processing resource: Test Resource (ID: 123)')
    end
  end
end
