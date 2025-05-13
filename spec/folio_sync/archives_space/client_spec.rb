# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FolioSync::ArchivesSpace::Client do
  let(:base_url) { 'https://example-test.example.com/api' }
  let(:archives_space_configuration) do
    ArchivesSpace::Configuration.new({
      base_uri: base_url,
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
      'ASPACE_BASE_API' => base_url,
      'ASPACE_API_USERNAME' => username,
      'ASPACE_API_PASSWORD' => password,
      'ASPACE_TIMEOUT' => timeout
    })
  end

  it 'is a subclass of ArchivesSpace::Client' do
    expect(described_class).to be < ArchivesSpace::Client
  end

  describe '#initialize' do
    it 'can be instantiated' do
      expect(instance).to be_a(described_class)
    end
  end

  describe '.instance' do
    let(:client_instance) { instance_double(described_class) }

    before do
      allow(described_class).to receive(:new).and_return(client_instance)
      allow(client_instance).to receive(:login)
    end

    it 'returns the same instance every time it is called' do
      inst = described_class.instance
      expect(inst).to be(client_instance) # Compare with the mocked instance
      expect(described_class.instance).to be(client_instance)
    end
  end

  describe '#get_all_repositories' do
    let(:response) { instance_double('Response') }
    let(:repositories) do
      [
        { 'uri' => '/repositories/1', 'name' => 'Repository 1' },
        { 'uri' => '/repositories/2', 'name' => 'Repository 2' }
      ]
    end

    before do
      allow(instance).to receive(:get).with('repositories').and_return(response)
      allow(response).to receive_messages(status_code: 200, parsed: repositories)
    end

    it 'fetches all repositories from ArchivesSpace' do
      result = instance.get_all_repositories
      expect(result).to eq(repositories)
    end

    it 'raises an error if the response status code is not 200' do
      allow(response).to receive_messages(status_code: 500, body: 'Internal Server Error')

      expect {
        instance.get_all_repositories
      }.to raise_error(FolioSync::Exceptions::ArchivesSpaceRequestError,
                       'Error fetching repositories: Internal Server Error')
    end
  end

  describe '#fetch_marc_xml_resource' do
    let(:repo_id) { '1' }
    let(:resource_id) { '123' }
    let(:response) { instance_double('Response') }
    let(:marc_data) do
      <<-XML
        <record>
          <controlfield tag="001">123456</controlfield>
          <datafield tag="245">
            <subfield code="a">Title of the Resource</subfield>
          </datafield>
        </record>
      XML
    end

    before do
      allow(instance).to receive(:get).with("repositories/#{repo_id}/resources/marc21/#{resource_id}.xml").and_return(response)
      allow(response).to receive_messages(status_code: 200, body: marc_data)
    end

    it 'fetches MARC data for the given repository and resource' do
      result = instance.fetch_marc_xml_resource(repo_id, resource_id)
      expect(result).to eq(marc_data)
    end

    it 'raises an error if the response status code is not 200' do
      allow(response).to receive_messages(status_code: 404, body: 'Not Found')

      expect {
        instance.fetch_marc_xml_resource(repo_id, resource_id)
      }.to raise_error(FolioSync::Exceptions::ArchivesSpaceRequestError,
                       'Failed to fetch MARC data for resource 123: Not Found')
    end
  end

  describe '#retrieve_paginated_resources' do
    let(:query_params) { { q: 'primary_type:resource', page: 1, page_size: 2 } }
    let(:response_page_1) { instance_double('Response') }
    let(:response_page_2) { instance_double('Response') }
    let(:resources_page_1) do
      [{ 'uri' => "/repositories/#{repository_id}/resources/1" },
       { 'uri' => "/repositories/#{repository_id}/resources/2" }]
    end
    let(:resources_page_2) do
      [{ 'uri' => "/repositories/#{repository_id}/resources/3" },
       { 'uri' => "/repositories/#{repository_id}/resources/4" }]
    end

    let(:response_body_page_1) do
      {
        'results' => resources_page_1,
        'this_page' => 1,
        'last_page' => 2,
        'page_size' => 2,
        'total_hits' => 4
      }
    end

    let(:response_body_page_2) do
      {
        'results' => resources_page_2,
        'this_page' => 2,
        'last_page' => 2,
        'page_size' => 2,
        'total_hits' => 4
      }
    end

    before do
      allow(instance).to receive(:get).with(
        "repositories/#{repository_id}/search",
        { query: { q: 'primary_type:resource', page: 1, page_size: 2 } }
      ).and_return(response_page_1)

      allow(response_page_1).to receive_messages(status_code: 200, parsed: response_body_page_1)

      allow(instance).to receive(:get).with(
        "repositories/#{repository_id}/search",
        { query: { q: 'primary_type:resource', page: 2, page_size: 2 } }
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
