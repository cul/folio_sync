# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FolioSync::ArchivesSpace::ResourceFetcher do
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

    it 'stores the instance directory' do
      instance = described_class.new(instance_key)
      expect(instance.instance_variable_get(:@instance_key)).to eq(instance_key)
    end
  end

  describe '#fetch_and_save_recent_resources' do
    let(:instance) { described_class.new(instance_key) }
    let(:repositories) do
      [
        { 'uri' => '/repositories/1', 'publish' => true },
        { 'uri' => '/repositories/2', 'publish' => false }
      ]
    end
    let(:modified_since) { Time.utc(2023, 1, 1) }

    before do
      allow(client).to receive(:fetch_all_repositories).and_return(repositories)
      allow(instance).to receive(:log_repository_skip)
      allow(instance).to receive(:fetch_and_save_resources_from_repository)
      allow(instance).to receive(:extract_id).and_return('1', '2')
    end

    it 'fetches all repositories from the ArchivesSpace client' do
      instance.fetch_and_save_recent_resources(modified_since)
      expect(client).to have_received(:fetch_all_repositories)
    end

    it 'processes published repositories' do
      instance.fetch_and_save_recent_resources(modified_since)
      expect(instance).to have_received(:fetch_and_save_resources_from_repository).with('1', modified_since)
    end

    it 'skips unpublished repositories' do
      instance.fetch_and_save_recent_resources(modified_since)
      expect(instance).to have_received(:log_repository_skip).with(repositories[1])
    end

    it 'extracts repository IDs from URIs' do
      instance.fetch_and_save_recent_resources(modified_since)
      expect(instance).to have_received(:extract_id).with('/repositories/1')
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
        fields: %w[id identifier system_mtime title publish json]
      })
    end

    it 'builds query parameters without a modification time filter when modified_since is nil' do
      instance = described_class.new(instance_key)
      result = instance.send(:build_query_params, nil)

      expect(result).to eq({
        q: 'primary_type:resource suppressed:false',
        page: 1,
        page_size: described_class::PAGE_SIZE,
        fields: %w[id identifier system_mtime title publish json]
      })
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