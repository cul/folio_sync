require 'rails_helper'

RSpec.describe FolioSync::ArchivesSpace::Client do
  let(:base_uri) { 'https://example-test.example.com/api' }
  let(:archives_space_configuration) do
    ArchivesSpace::Configuration.new({
      base_uri: base_uri,
      username: username,
      password: password,
      timeout: timeout
    })
  end
  let(:instance) { described_class.new(archives_space_configuration) }
  let(:repository_id) { 2 }
  let(:resource_id) { 4656 }
  let(:valid_resource_record_uri) { "/repositories/#{repository_id}/resources/#{resource_id}" }
  let(:invalid_resource_record_uri) { "Oh no! This can't be valid!" }
  let(:username) { 'username' }
  let(:password) { 'password' }
  let(:timeout)  { 10 }

  before do
    allow(Rails.configuration).to receive(:archivesspace).and_return({
      "ASPACE_BASE_API" => base_uri,
      "ASPACE_API_USERNAME" => username,
      "ASPACE_API_PASSWORD" => password,
      "ASPACE_TIMEOUT" => timeout
    })
  end

  it 'is a subclass of ArchivesSpace::Client' do
    expect(described_class).to be < ArchivesSpace::Client
  end

  describe "#initialize" do
    it 'can be instantiated' do
      expect(instance).to be_a(described_class)
    end
  end

  describe ".instance" do
    before do
      allow_any_instance_of(described_class).to receive(:login)
    end

    it 'returns the same instance every time it is called' do
      inst = described_class.instance
      expect(inst).to be_a(described_class)
      expect(described_class.instance).to be(inst)
    end
  end


  describe "#retrieve_paginated_resources" do
    let(:query_params) { { query: { q: "primary_type:resource", page: 1, page_size: 2 } } }
    let(:response_page_1) { double('Response') }
    let(:response_page_2) { double('Response') }
    let(:resources_page_1) { [ { 'uri' => "/repositories/#{repository_id}/resources/1" }, { 'uri' => "/repositories/#{repository_id}/resources/2" } ] }
    let(:resources_page_2) { [ { 'uri' => "/repositories/#{repository_id}/resources/3" }, { 'uri' => "/repositories/#{repository_id}/resources/4" } ] }

    let(:response_body_page_1) do
      {
        "results" => resources_page_1,
        "this_page" => 1,
        "last_page" => 2,
        "page_size" => 2,
        "total_hits" => 4
      }
    end

    let(:response_body_page_2) do
      {
        "results" => resources_page_2,
        "this_page" => 2,
        "last_page" => 2,
        "page_size" => 2,
        "total_hits" => 4
      }
    end

    before do
      allow(instance).to receive(:get).with(
        "repositories/#{repository_id}/search",
        { query: { q: "primary_type:resource", page: 1, page_size: 2 } }
      ).and_return(response_page_1)

      allow(response_page_1).to receive_messages(status_code: 200, parsed: response_body_page_1)

      allow(instance).to receive(:get).with(
        "repositories/#{repository_id}/search",
        { query: { q: "primary_type:resource", page: 2, page_size: 2 } }
      ).and_return(response_page_2)

      allow(response_page_2).to receive_messages(status_code: 200, parsed: response_body_page_2)
    end

    it 'handles pagination correctly' do
      results = []
      instance.retrieve_paginated_resources(repository_id, query_params) do |resources|
        results.concat(resources)
      end
      expect(results).to eq(resources_page_1 + resources_page_2)
    end
  end
end
