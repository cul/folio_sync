# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FolioSync::Folio::Reader do
  let(:instance) { described_class.new }
  let(:folio_client) { instance_double(FolioSync::Folio::Client) }
  let(:hrid) { '123456' }
  let(:repo_key) { 'test_repo' }
  let(:marc_record) { double('MARC::Record') }
  let(:marc_json_hash) do
    { 'fields' => [{ '001' => '123456789' }, { '005' => '20240625231052.0' }] }
  end
  let(:source_record) do
    { 'parsedRecord' => { 'content' => marc_json_hash } }
  end
  let (:item_requests) do
    [
      { 'id' => 'req1', 'item' => { 'barcode' => 'ITEM123' }, 'requester' => { 'barcode' => 'REQ001' }, 'status' => 'Open - Not yet filled' },
      { 'id' => 'req2', 'item' => { 'barcode' => 'ITEM456' }, 'requester' => { 'barcode' => 'REQ001' }, 'status' => 'Open - Not yet filled' }
    ]
  end

  before do
    allow(FolioSync::Folio::Client).to receive(:instance).and_return(folio_client)
    allow(folio_client).to receive(:find_source_record).with(instance_record_hrid: hrid).and_return(source_record)
    allow(MARC::Record).to receive(:new_from_hash).with(marc_json_hash).and_return(marc_record)
  end

  describe '#initialize' do
    it 'initializes with the FOLIO client' do
      expect(instance.instance_variable_get(:@client)).to eq(folio_client)
    end
  end

  describe '#get_marc_record' do
    it 'fetches the MARC record for the given HRID' do
      result = instance.get_marc_record(hrid)
      expect(result).to eq(marc_record)
      expect(folio_client).to have_received(:find_source_record).with(instance_record_hrid: hrid)
    end

    it 'raises an error if the MARC record is not found' do
      allow(folio_client).to receive(:find_source_record).with(instance_record_hrid: hrid).and_return(nil)

      result = instance.get_marc_record(hrid)
      expect(result).to be_nil
      expect(folio_client).to have_received(:find_source_record).with(instance_record_hrid: hrid)
    end
  end

  describe '#retrieve_circulation_requests' do
    let(:folio_requests_config) do
      {
        repos: {
          repo_key.to_sym => {
            service_point_id: service_point_id,
            user_barcode: barcode
          }
        }
      }
    end

    before do
      # Update Rails configuration mock for the custom repo
      allow(Rails).to receive(:configuration).and_return(
        double(folio_requests: folio_requests_config)
      )

      allow(folio_client).to receive(:get).with(
        '/circulation/requests',
        { limit: 1000, query: "requester.barcode=#{barcode} and status=\"Open - Not yet filled\"" }
      ).and_return({ 'requests' => item_requests })
    end

    context 'when using a specific repository configuration' do
      let(:repo_key) { 'custom_repo' }
      let(:barcode) { 'CUSTOM123' }
      let(:service_point_id) { 'custom-service-point-id' }

      it 'retrieves circulation requests filtered by the repository user barcode' do
        result = instance.retrieve_circulation_requests(repo_key)

        expect(result).to eq(item_requests)
        expect(folio_client).to have_received(:get).with(
          '/circulation/requests',
          { limit: 1000, query: "requester.barcode=#{barcode} and status=\"Open - Not yet filled\"" }
        )
        expect(result.length).to eq(2)
      end
    end
  end
end
