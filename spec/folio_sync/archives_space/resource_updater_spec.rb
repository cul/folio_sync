# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FolioSync::ArchivesSpace::ResourceUpdater do
  include_context 'FolioSync directory setup'

  let(:instance_key) { 'cul' }
  let(:client) { instance_double(FolioSync::ArchivesSpace::Client) }
  let(:logger) { instance_double(Logger, info: nil, error: nil) }
  let(:record) do
    instance_double(
      AspaceToFolioRecord,
      id: 42,
      repository_key: 1,
      resource_key: 123,
      folio_hrid: 'hrid1',
    )
  end

  before do
    allow(Logger).to receive(:new).and_return(logger)
    allow(FolioSync::ArchivesSpace::Client).to receive(:new).and_return(client)
  end

  describe '#initialize' do
    it 'can be instantiated with an instance key' do
      instance = described_class.new(instance_key)
      expect(instance).to be_a(described_class)
    end

    it 'sets up logger, client, and errors array' do
      updater = described_class.new(instance_key)
      expect(updater.instance_variable_get(:@logger)).to eq(logger)
      expect(updater.instance_variable_get(:@client)).to eq(client)
      expect(updater.updating_errors).to eq([])
    end
  end

  describe '#update_single_record' do
    it 'calls update_archivesspace_resource' do
      updater = described_class.new(instance_key)
      allow(updater).to receive(:update_archivesspace_resource)

      updater.update_single_record(record)
      expect(updater).to have_received(:update_archivesspace_resource).with(record)
      expect(logger).to have_received(:info).with("Successfully updated ArchivesSpace record #{record.id}")
    end
  end

  describe '#update_archivesspace_resource' do
    it 'calls update_id_fields for cul' do
      updater = described_class.new('cul')
      expect(updater).to receive(:update_id_fields).with(record)
      updater.update_archivesspace_resource(record)
    end

    it 'calls update_string_1_field for barnard' do
      updater = described_class.new('barnard')
      expect(updater).to receive(:update_string_1_field).with(record)
      updater.update_archivesspace_resource(record)
    end

    it 'raises error for unknown instance_key' do
      updater = described_class.new('unknown')
      expect { updater.update_archivesspace_resource(record) }.to raise_error(ArgumentError)
    end
  end

  describe '#update_resource_with_folio_data' do
    it 'yields resource_data, updates boolean_1, and calls client.update_resource' do
      updater = described_class.new(instance_key)
      resource_data = { 'user_defined' => { 'foo' => 'bar' } }

      expect(client).to receive(:fetch_resource).with(1, 123).and_return(resource_data)
      expect(client).to receive(:update_resource) do |repo_id, res_id, data|
        expect(data['user_defined']['boolean_1']).to eq(true)
        expect(data['id_0']).to eq('hrid1')
      end
      updater.update_resource_with_folio_data(1, 123) do |data|
        data.merge('id_0' => 'hrid1', 'ead_id' => 'hrid1')
      end
    end
  end

  describe '#update_id_fields' do
    it 'calls update_resource_with_folio_data with correct params' do
      updater = described_class.new('cul')
      expect(updater).to receive(:update_resource_with_folio_data).with(1, 123)
      updater.update_id_fields(record)
    end
  end

  describe '#update_string_1_field' do
    it 'calls update_resource_with_folio_data with correct params' do
      updater = described_class.new('barnard')
      expect(updater).to receive(:update_resource_with_folio_data).with(1, 123)
      updater.update_string_1_field(record)
    end
  end
end