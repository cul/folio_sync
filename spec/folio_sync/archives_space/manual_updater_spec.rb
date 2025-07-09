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

    it 'sets the correct CSV file path' do
      instance = described_class.new(instance_key)
      expected_path = Rails.root.join("tmp/#{instance_key}_updated_aspace_resources_20250701000000.csv")
      expect(instance.instance_variable_get(:@csv_file_path)).to eq(expected_path)
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
    let(:csv_mock) { instance_double(CSV) }

    before do
      allow(aspace_client).to receive(:fetch_all_repositories).and_return(repositories)
      allow(instance).to receive(:log_repository_skip)
      allow(instance).to receive(:fetch_from_repo_and_update_resources)
      allow(instance).to receive(:extract_id).and_return('1', '2')
      allow(CSV).to receive(:open).and_yield(csv_mock)
      allow(csv_mock).to receive(:<<)
    end

    it 'opens CSV file and writes headers' do
      instance.retrieve_and_sync_aspace_resources
      expect(CSV).to have_received(:open).with(instance.instance_variable_get(:@csv_file_path), 'w')
      expect(csv_mock).to have_received(:<<).with(['Resource URI', 'HRID'])
    end

    it 'fetches all repositories from the ArchivesSpace client' do
      instance.retrieve_and_sync_aspace_resources
      expect(aspace_client).to have_received(:fetch_all_repositories)
    end

    it 'processes published repositories' do
      instance.retrieve_and_sync_aspace_resources
      expect(instance).to have_received(:fetch_from_repo_and_update_resources).with('1', csv_mock)
    end

    it 'skips unpublished repositories' do
      instance.retrieve_and_sync_aspace_resources
      expect(instance).to have_received(:log_repository_skip).with(repositories[1])
    end
  end

  describe '#fetch_from_repo_and_update_resources' do
    let(:instance_key) { 'cul' }
    let(:instance) { described_class.new(instance_key) }
    let(:repo_id) { '1' }
    let(:csv_mock) { instance_double(CSV) }
    let(:resources) do
      [
        { 'id' => '123', 'title' => 'Resource 1', 'suppressed' => false, 'id_0' => 'HRID123', 'uri' => '/repositories/1/resources/123', 'user_defined' => { 'boolean_1' => false } },
        { 'id' => '456', 'title' => 'Resource 2', 'suppressed' => true, 'id_0' => 'HRID456', 'uri' => '/repositories/1/resources/456', 'user_defined' => { 'boolean_1' => false } }
      ]
    end

    before do
      allow(aspace_client).to receive(:retrieve_resources_for_repository).and_yield(resources)
      allow(folio_client).to receive(:find_source_record).and_return(true, nil)
      allow(instance).to receive(:update_aspace_record)
      allow(instance).to receive(:write_to_csv)
      allow(csv_mock).to receive(:<<)
    end

    it 'processes resources that have corresponding FOLIO records' do
      instance.fetch_from_repo_and_update_resources(repo_id, csv_mock)
      expect(instance).to have_received(:update_aspace_record).with(resources[0], repo_id)
      expect(instance).to have_received(:write_to_csv).with(resources[0], 'HRID123', csv_mock)
    end

    it 'skips suppressed resources' do
      instance.fetch_from_repo_and_update_resources(repo_id, csv_mock)
      expect(instance).not_to have_received(:update_aspace_record).with(resources[1], repo_id)
    end

    it 'skips resources without corresponding FOLIO records' do
      # Second resource returns nil from FOLIO
      instance.fetch_from_repo_and_update_resources(repo_id, csv_mock)
      expect(instance).not_to have_received(:update_aspace_record).with(resources[1], repo_id)
    end
  end

  describe '#update_aspace_record' do
    let(:repo_id) { '1' }

    before do
      allow(aspace_client).to receive(:update_resource)
    end

    context 'when instance_key is "cul"' do
      let(:instance_key) { 'cul' }
      let(:instance) { described_class.new(instance_key) }

      it 'creates user_defined and sets boolean_1 to true when user_defined is missing' do
        resource = { 'id' => '123', 'uri' => '/repositories/1/resources/123' }
        instance.update_aspace_record(resource, repo_id)
        
        expect(resource['user_defined']).to eq({ 'boolean_1' => true })
        expect(aspace_client).to have_received(:update_resource).with(repo_id, '123', resource)
      end

      it 'preserves existing user_defined fields and sets boolean_1 to true' do
        resource = { 'id' => '123', 'user_defined' => { 'string_1' => 'existing' }, 'uri' => '/repositories/1/resources/123' }
        instance.update_aspace_record(resource, repo_id)
        
        expect(resource['user_defined']).to eq({ 'string_1' => 'existing', 'boolean_1' => true })
        expect(aspace_client).to have_received(:update_resource).with(repo_id, '123', resource)
      end
    end

    context 'when instance_key is "barnard"' do
      let(:instance_key) { 'barnard' }
      let(:instance) { described_class.new(instance_key) }

      it 'sets boolean_1 to true in existing user_defined' do
        resource = { 'id' => '123', 'user_defined' => { 'string_1' => 'BC456' }, 'uri' => '/repositories/1/resources/123' }
        instance.update_aspace_record(resource, repo_id)
        
        expect(resource['user_defined']).to eq({ 'string_1' => 'BC456', 'boolean_1' => true })
        expect(aspace_client).to have_received(:update_resource).with(repo_id, '123', resource)
      end
    end
  end

  describe '#determine_potential_hrid' do
    let(:instance) { described_class.new(instance_key) }

    context 'when instance_key is "cul"' do
      let(:instance_key) { 'cul' }
      let(:resource) { { 'id_0' => 'CUL123' } }

      it 'returns the id_0 value' do
        expect(instance.determine_potential_hrid(resource)).to eq('CUL123')
      end
    end

    context 'when instance_key is "barnard"' do
      let(:instance_key) { 'barnard' }
      let(:resource) { { 'user_defined' => { 'string_1' => 'BC456' } } }

      it 'returns the user_defined string_1 value' do
        expect(instance.determine_potential_hrid(resource)).to eq('BC456')
      end

      it 'returns nil if string_1 is not present' do
        resource_without_string_1 = { 'user_defined' => {} }
        expect(instance.determine_potential_hrid(resource_without_string_1)).to be_nil
      end
    end

    context 'when instance_key is neither "cul" nor "barnard"' do
      let(:instance_key) { 'other' }
      let(:resource) { { 'id_0' => 'OTHER123' } }

      it 'returns nil' do
        expect(instance.determine_potential_hrid(resource)).to be_nil
      end
    end
  end

  describe '#write_to_csv' do
    let(:instance) { described_class.new(instance_key) }
    let(:resource) { { 'uri' => '/repositories/1/resources/123' } }
    let(:hrid) { 'HRID123' }
    let(:csv_mock) { instance_double(CSV) }

    before do
      allow(csv_mock).to receive(:<<)
    end

    it 'writes the resource URI and HRID to the CSV' do
      instance.write_to_csv(resource, hrid, csv_mock)
      expect(csv_mock).to have_received(:<<).with(['/repositories/1/resources/123', 'HRID123'])
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

  describe 'CSV generation integration test' do
    let(:instance_key) { 'cul' }
    let(:test_output_file) { Rails.root.join('tmp', 'test_output.csv') }
    let(:expected_fixture_file) { Rails.root.join('spec', 'fixtures', 'archives_space', 'manual_updater', 'manual_updater', 'expected_updated_aspace_resources.csv') }
    
    let(:repositories) do
      [
        { 'uri' => '/repositories/1', 'publish' => true },
        { 'uri' => '/repositories/2', 'publish' => true },
        { 'uri' => '/repositories/3', 'publish' => true }
      ]
    end
    
    let(:resources_repo_1) do
      [
        { 
          'id' => '123', 
          'title' => 'Resource 1', 
          'suppressed' => false, 
          'id_0' => '111222', 
          'uri' => '/repositories/1/resources/123',
          'user_defined' => { 'boolean_1' => false }
        }
      ]
    end
    
    let(:resources_repo_2) do
      [
        { 
          'id' => '456', 
          'title' => 'Resource 2', 
          'suppressed' => false, 
          'id_0' => '333444', 
          'uri' => '/repositories/2/resources/456',
          'user_defined' => { 'boolean_1' => false }
        }
      ]
    end
    
    let(:resources_repo_3) do
      [
        { 
          'id' => '789', 
          'title' => 'Resource 3', 
          'suppressed' => false, 
          'id_0' => '555666', 
          'uri' => '/repositories/3/resources/789',
          'user_defined' => { 'boolean_1' => false }
        }
      ]
    end

    before do
      allow(aspace_client).to receive(:fetch_all_repositories).and_return(repositories)
      allow(aspace_client).to receive(:retrieve_resources_for_repository).with('1', anything).and_yield(resources_repo_1)
      allow(aspace_client).to receive(:retrieve_resources_for_repository).with('2', anything).and_yield(resources_repo_2)
      allow(aspace_client).to receive(:retrieve_resources_for_repository).with('3', anything).and_yield(resources_repo_3)
      allow(folio_client).to receive(:find_source_record).and_return(true)
      allow(aspace_client).to receive(:update_resource)
    end

    after do
      File.delete(test_output_file) if File.exist?(test_output_file)
    end

    it 'generates a CSV file with content matching the expected fixture' do
      instance = described_class.new(instance_key)
      instance.instance_variable_set(:@csv_file_path, test_output_file)
      instance.retrieve_and_sync_aspace_resources

      expect(File.exist?(test_output_file)).to be true

      expected_content = File.read(expected_fixture_file).strip
      actual_content = File.read(test_output_file).strip

      expect(actual_content).to eq(expected_content)
    end

    it 'generates CSV with correct headers and data rows' do
      # Create the instance and override the CSV file path
      instance = described_class.new(instance_key)
      instance.instance_variable_set(:@csv_file_path, test_output_file)
      instance.retrieve_and_sync_aspace_resources
      csv_data = CSV.read(test_output_file, headers: true)
      
      expect(csv_data.headers).to eq(['Resource URI', 'HRID'])
      expect(csv_data.length).to eq(3)

      # Verify specific rows
      expect(csv_data[0]['Resource URI']).to eq('/repositories/1/resources/123')
      expect(csv_data[0]['HRID']).to eq('111222')

      expect(csv_data[1]['Resource URI']).to eq('/repositories/2/resources/456')
      expect(csv_data[1]['HRID']).to eq('333444')

      expect(csv_data[2]['Resource URI']).to eq('/repositories/3/resources/789')
      expect(csv_data[2]['HRID']).to eq('555666')
    end
  end

  describe '#should_process_resource?' do
    let(:instance) { described_class.new(instance_key) }

    context 'when instance_key is "cul"' do
      let(:instance_key) { 'cul' }

      it 'returns true for valid CUL resource' do
        resource = { 'suppressed' => false, 'id_0' => 'CUL123', 'user_defined' => { 'boolean_1' => false } }
        expect(instance.should_process_resource?(resource)).to be true
      end

      it 'returns false for suppressed resource' do
        resource = { 'suppressed' => true, 'id_0' => 'CUL123', 'user_defined' => { 'boolean_1' => false } }
        expect(instance.should_process_resource?(resource)).to be false
      end

      it 'returns false for already processed resource' do
        resource = { 'suppressed' => false, 'id_0' => 'CUL123', 'user_defined' => { 'boolean_1' => true } }
        expect(instance.should_process_resource?(resource)).to be false
      end

      it 'returns true for CUL resource without user_defined' do
        resource = { 'suppressed' => false, 'id_0' => 'CUL123' }
        expect(instance.should_process_resource?(resource)).to be true
      end
    end

    context 'when instance_key is "barnard"' do
      let(:instance_key) { 'barnard' }

      it 'returns true for valid Barnard resource' do
        resource = { 'suppressed' => false, 'user_defined' => { 'string_1' => 'BC456', 'boolean_1' => false } }
        expect(instance.should_process_resource?(resource)).to be true
      end

      it 'returns false for Barnard resource without user_defined' do
        resource = { 'suppressed' => false, 'id_0' => 'BC456' }
        expect(instance.should_process_resource?(resource)).to be false
      end

      it 'returns false for Barnard resource without string_1' do
        resource = { 'suppressed' => false, 'user_defined' => { 'boolean_1' => false } }
        expect(instance.should_process_resource?(resource)).to be false
      end
    end
  end
end