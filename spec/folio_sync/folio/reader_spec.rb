# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FolioSync::Folio::Reader do
  let(:instance) { described_class.new }
  let(:folio_client) { instance_double(FolioSync::Folio::Client) }
  let(:hrid) { '123456' }
  let(:marc_record) { double('MARC::Record') }
  let(:marc_json_hash) do
    { 'fields' => [{ '001' => '123456789' }, { '005' => '20240625231052.0' }] }
  end
  let(:source_record) do
      { 'parsedRecord' => { 'content' => marc_json_hash } }
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
end
