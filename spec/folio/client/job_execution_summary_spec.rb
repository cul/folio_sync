# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Folio::Client::JobExecutionSummary do
  let(:test_raw_results) do
    [
      { 'sourceRecordOrder' => 1, 'relatedInstanceInfo' => { 'actionStatus' => 'CREATED', 'hridList' => ['hrid1'], 'idList' => ['id1'] } },
      { 'sourceRecordOrder' => 2, 'relatedInstanceInfo' => { 'actionStatus' => 'UPDATED', 'hridList' => ['hrid2'], 'idList' => ['id2'] } }
    ]
  end
  let(:test_custom_metadata) do
    [
      {
        "respository_key" => 1,
        "resource_key" => 123,
        "hrid": 'test123456789',
        "suppressDiscovery" => false
      },
      {
        "respository_key" => 2,
        "resource_key" => 456,
        "hrid": 'test987654321',
        "suppressDiscovery" => true
      }
    ]
  end

  subject(:summary) { described_class.new(test_raw_results, test_custom_metadata) }

  describe '#initialize' do
    it 'can be instantiated with entries response and custom metadata' do
      instance = described_class.new(test_raw_results, test_custom_metadata)
      expect(instance).to be_a(described_class)
    end

    it 'sorts raw_results by sourceRecordOrder' do
      unordered = [test_raw_results[1], test_raw_results[0]]
      instance = described_class.new(unordered, test_custom_metadata)
      expect(instance.raw_results.map { |r| r['sourceRecordOrder'] }).to eq([1, 2])
    end

    it 'sets records_processed to the number of results' do
      expect(summary.records_processed).to eq(2)
    end
  end

  describe '#each_result' do
    it 'yields each result with corresponding custom metadata and instance info' do
      yielded = []
      summary.each_result do |raw_result, custom_metadata, action_status, hrid_list, id_list|
        yielded << [raw_result, custom_metadata, action_status, hrid_list, id_list]
      end

      expect(yielded.size).to eq(2)
      expect(yielded[0][0]['sourceRecordOrder']).to eq(1)
      expect(yielded[0][1]).to eq(test_custom_metadata[1]) # index by sourceRecordOrder (1)
      expect(yielded[0][2]).to eq('CREATED')
      expect(yielded[0][3]).to eq(['hrid1'])
      expect(yielded[0][4]).to eq(['id1'])

      expect(yielded[1][0]['sourceRecordOrder']).to eq(2)
      expect(yielded[1][1]).to eq(test_custom_metadata[2] || {}) # index by sourceRecordOrder (2), fallback to {}
      expect(yielded[1][2]).to eq('UPDATED')
      expect(yielded[1][3]).to eq(['hrid2'])
      expect(yielded[1][4]).to eq(['id2'])
    end
  end
end