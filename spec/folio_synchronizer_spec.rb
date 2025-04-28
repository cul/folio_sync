require 'rails_helper'

RSpec.describe FolioSync::FolioSynchronizer do
  let(:instance) { described_class.new }
  let(:aspace_client) { instance_double(FolioSync::ArchivesSpace::Client) }
  let(:logger) { instance_double(Logger, info: nil) }

  before do
    allow(FolioSync::ArchivesSpace::Client).to receive(:instance).and_return(aspace_client)
    allow(Logger).to receive(:new).and_return(logger)
  end

  describe "#initialize" do
    it 'can be instantiated' do
      expect(instance).to be_a(described_class)
    end

    it 'initializes with the ArchivesSpace client' do
      synchronizer = described_class.new
      expect(synchronizer.instance_variable_get(:@aspace_client)).to eq(aspace_client)
    end

    it 'initializes with a logger' do
      expect(instance.instance_variable_get(:@logger)).to eq(logger)
    end
  end

  describe "#fetch_recent_marc_resources" do
    let(:repositories) { [{ "uri" => "/repositories/1", "publish" => true }, { "uri" => "/repositories/2", "publish" => false }] }

    before do
      allow(aspace_client).to receive(:get_all_repositories).and_return(repositories)
      allow(instance).to receive(:fetch_resources_for_repo)
      allow(instance).to receive(:log_repository_skip)
    end

    it 'fetches all repositories from the ArchivesSpace client' do
      instance.fetch_recent_marc_resources
      expect(aspace_client).to have_received(:get_all_repositories)
    end

    it 'processes published repositories' do
      instance.fetch_recent_marc_resources
      expect(instance).to have_received(:fetch_resources_for_repo).with("1")
    end

    it 'skips unpublished repositories' do
      instance.fetch_recent_marc_resources
      expect(instance).to have_received(:log_repository_skip).with(repositories[1])
    end
  end

  describe "#fetch_resources_for_repo" do
    let(:repo_id) { "1" }
    let(:resources) { [{ "uri" => "/resources/1", "title" => "Resource 1", "id" => "1" }] }
    let(:query_params) { { query: { q: "test_query", page: 1, page_size: 20 } } }

    before do
      allow(Time).to receive(:now).and_return(Time.utc(2023, 1, 1))
      allow(instance).to receive(:build_query_params).and_return(query_params)
      allow(aspace_client).to receive(:retrieve_paginated_resources).and_yield(resources)
      allow(instance).to receive(:log_resource_processing)
      allow(instance).to receive(:fetch_and_save_marc)
    end

    it 'builds query parameters for the last 24 hours' do
      instance.send(:fetch_resources_for_repo, repo_id)
      expect(instance).to have_received(:build_query_params).with(Time.utc(2023, 1, 1) - described_class::ONE_DAY_IN_SECONDS * 8)
    end

    it 'retrieves paginated resources from the ArchivesSpace client' do
      instance.send(:fetch_resources_for_repo, repo_id)
      expect(aspace_client).to have_received(:retrieve_paginated_resources).with(repo_id, query_params)
    end

    it 'logs each resource being processed' do
      instance.send(:fetch_resources_for_repo, repo_id)
      expect(instance).to have_received(:log_resource_processing).with(resources[0])
    end

    it 'fetches and saves MARC data for each resource' do
      instance.send(:fetch_resources_for_repo, repo_id)
      expect(instance).to have_received(:fetch_and_save_marc).with(repo_id, "1")
    end
  end

  describe "#build_query_params" do
    let(:last_24h) { Time.utc(2023, 1, 1) }

    it 'builds the correct query parameters' do
      result = instance.send(:build_query_params, last_24h)
      expect(result).to eq({
        query: {
          q: "primary_type:resource suppressed:false system_mtime:[2023-01-01T00:00:00.000Z TO *]",
          page: 1,
          page_size: described_class::PAGE_SIZE,
          fields: %w[id system_mtime title publish]
        }
      })
    end
  end
end