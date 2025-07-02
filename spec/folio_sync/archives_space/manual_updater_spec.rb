# frozen_string_literal: true

require 'rails_helper'
require 'csv'

RSpec.describe FolioSync::ArchivesSpace::ManualUpdater do
  let(:instance_key) { 'instance1' }
  let(:aspace_client) { instance_double(FolioSync::ArchivesSpace::Client) }
  let(:folio_client) { instance_double(FolioSync::Folio::Client) }
  let(:logger) { instance_double(Logger, info: nil, warn: nil, error: nil) }
  let(:csv_file_path) { "tmp/test/#{instance_key}_updated_aspace_resources_#{Time.zone.now.strftime('%Y%m%d%H%M%S')}.csv" }

  before do
    allow(Logger).to receive(:new).and_return(logger)
    allow(FolioSync::ArchivesSpace::Client).to receive(:new).with(instance_key).and_return(aspace_client)
    allow(FolioSync::Folio::Client).to receive(:instance).and_return(folio_client)

    # Freeze time to ensure consistent CSV file path
    frozen_time = Time.zone.local(2025, 7, 1, 0, 0, 0)
    allow(Time.zone).to receive(:now).and_return(frozen_time)
    allow(CSV).to receive(:open).and_return(nil)
  end

  after do
    File.delete(csv_file_path) if File.exist?(csv_file_path)
  end

  describe '#initialize' do
    it 'initializes with the correct instance key and clients' do
      instance = described_class.new(instance_key)
      expect(instance.instance_variable_get(:@instance_key)).to eq(instance_key)
      expect(instance.instance_variable_get(:@aspace_client)).to eq(aspace_client)
      expect(instance.instance_variable_get(:@folio_client)).to eq(folio_client)
    end

    it 'initializes the CSV file with headers' do
      allow(CSV).to receive(:open).and_call_original
      instance = described_class.new(instance_key)
      expect(CSV).to have_received(:open).with(instance.instance_variable_get(:@csv_file_path), 'w')
    end
  end

  describe '#retrieve_and_sync_aspace_resources' do
    let(:instance) { described_class.new(instance_key) }
    let(:repositories) do
      [
        { 'uri' => '/repositories/1', 'publish' => true },
        { 'uri' => '/repositories/2', 'publish' => false }
      ]
    end

    before do
      allow(aspace_client).to receive(:fetch_all_repositories).and_return(repositories)
      allow(instance).to receive(:log_repository_skip)
      allow(instance).to receive(:fetch_from_repo_and_update_resources)
      allow(instance).to receive(:extract_id).and_return('1', '2')
    end

    it 'fetches all repositories from the ArchivesSpace client' do
      instance.retrieve_and_sync_aspace_resources
      expect(aspace_client).to have_received(:fetch_all_repositories)
    end

    it 'processes published repositories' do
      instance.retrieve_and_sync_aspace_resources
      expect(instance).to have_received(:fetch_from_repo_and_update_resources).with('1')
    end

    it 'skips unpublished repositories' do
      instance.retrieve_and_sync_aspace_resources
      expect(instance).to have_received(:log_repository_skip).with(repositories[1])
    end
  end

  describe '#fetch_from_repo_and_update_resources' do
    let(:instance) { described_class.new(instance_key) }
    let(:repo_id) { '1' }
    let(:resources) do
      [
        { 'id' => '123', 'title' => 'Resource 1', 'suppressed' => false, 'id_0' => 'HRID123', 'uri' => '/repositories/1/resources/123' },
        { 'id' => '456', 'title' => 'Resource 2', 'suppressed' => true }
      ]
    end

    before do
      allow(aspace_client).to receive(:retrieve_resources_for_repository).and_yield(resources)
      allow(folio_client).to receive(:find_source_record).and_return(true, nil)
      allow(instance).to receive(:update_aspace_record)
      allow(CSV).to receive(:open).and_call_original
    end

    it 'writes updated resources to the CSV file' do
      allow(CSV).to receive(:open).and_call_original
      instance.fetch_from_repo_and_update_resources(repo_id)
      expect(CSV).to have_received(:open).with(instance.instance_variable_get(:@csv_file_path), 'a').at_least(:once)
    end

    it 'processes resources that have corresponding FOLIO records' do
      instance.fetch_from_repo_and_update_resources(repo_id)
      expect(instance).to have_received(:update_aspace_record).with(resources[0], repo_id)
    end

    it 'skips resources without corresponding FOLIO records' do
      instance.fetch_from_repo_and_update_resources(repo_id)
      expect(instance).not_to have_received(:update_aspace_record).with(resources[1], repo_id)
    end
  end

  describe '#update_aspace_record' do
    let(:instance) { described_class.new(instance_key) }
    let(:resource) { { 'id' => '123', 'user_defined' => {}, 'uri' => '/repositories/1/resources/123' } }
    let(:repo_id) { '1' }

    before do
      allow(aspace_client).to receive(:update_resource)
    end

    it 'updates the resource with the correct data' do
      instance.update_aspace_record(resource, repo_id)
      expect(aspace_client).to have_received(:update_resource).with(repo_id, '123', resource)
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
end
