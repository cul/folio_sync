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
      expect(instance.instance_variable_get(:@instance_dir)).to eq(instance_key)
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
  end
end