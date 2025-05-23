# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FolioSync::ArchivesSpace::Client do
  let(:instance_key) { 'instance1' }
  let(:base_url) { 'https://example1-test.library.edu/api' }
  let(:username) { 'example-user' }
  let(:password) { 'example-password' }
  let(:timeout) { 60 }
  let(:archivesspace_config) do
    {
      'instance1' => {
        base_url: base_url,
        username: username,
        password: password,
        timeout: timeout
      },
      'instance2' => {
        base_url: 'https://example2-test.library.edu/api',
        username: username,
        password: password,
        timeout: timeout
      }
    }
  end

  let(:repository_id) { 2 }
  let(:resource_id) { 4656 }

  before do
    allow(Rails.configuration).to receive(:archivesspace) do
      { instance_key => archivesspace_config[instance_key] }
    end
    allow_any_instance_of(described_class).to receive(:login)
  end

  it 'is a subclass of ArchivesSpace::Client' do
    expect(described_class).to be < ArchivesSpace::Client
  end

  describe '#initialize' do
    it 'can be instantiated with a valid instance key' do
      expect { described_class.new(instance_key) }.not_to raise_error
    end

    it 'raises an error when instance key is not found' do
      expect {
        described_class.new('nonexistent_instance')
      }.to raise_error(ArgumentError, "No ArchivesSpace config for instance 'nonexistent_instance'")
    end

    it 'calls login automatically during initialization' do
      expect_any_instance_of(described_class).to receive(:login)
      described_class.new(instance_key)
    end

    it 'creates ArchivesSpace::Configuration with correct parameters' do
      expected_config = {
        base_uri: base_url,
        username: username,
        password: password,
        timeout: timeout
      }
      allow(ArchivesSpace::Configuration).to receive(:new).and_call_original
      described_class.new(instance_key)
      expect(ArchivesSpace::Configuration).to have_received(:new).with(expected_config)
    end
  end

  describe '#get_all_repositories' do
    let(:instance) { described_class.new(instance_key) }
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
    let(:instance) { described_class.new(instance_key) }
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
    let(:instance) { described_class.new(instance_key) }
    let(:query_params) { { q: 'primary_type:resource', page_size: 2 } }
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
      allow(Rails.logger).to receive(:debug)
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

    it 'raises an error if the response status code is not 200' do
      error_response = instance_double('Response')
      allow(instance).to receive(:get).and_return(error_response)
      allow(error_response).to receive_messages(status_code: 500, body: 'Internal Server Error')

      expect {
        instance.retrieve_paginated_resources(repository_id, query_params) do |resources|
          # This block should not be called due to the error
        end
      }.to raise_error(FolioSync::Exceptions::ArchivesSpaceRequestError,
                       'Error fetching resources: Internal Server Error')
    end
  end

  describe '#handle_response' do
    let(:instance) { described_class.new(instance_key) }
    let(:response) { instance_double('Response') }

    it 'returns the response when status code is 200' do
      allow(response).to receive(:status_code).and_return(200)

      result = instance.send(:handle_response, response, 'Test error message')
      expect(result).to eq(response)
    end

    it 'raises an error when status code is not 200' do
      allow(response).to receive_messages(status_code: 404, body: 'Not Found')

      expect {
        instance.send(:handle_response, response, 'Test error message')
      }.to raise_error(FolioSync::Exceptions::ArchivesSpaceRequestError,
                       'Test error message: Not Found')
    end
  end
end
