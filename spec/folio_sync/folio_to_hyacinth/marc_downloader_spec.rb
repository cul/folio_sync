# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FolioSync::FolioToHyacinth::MarcDownloader do
  let(:instance) { described_class.new }
  let(:folio_client) { instance_double(FolioSync::Folio::Client) }
  let(:folio_reader) { instance_double(FolioSync::Folio::Reader) }
  let(:value_965_hyacinth) { '965hyacinth' }
  let(:folio_to_hyacinth_config) { { download_directory: '/tmp/folio_to_hyacinth/downloads' } }

  let(:marc_record_with_965hyacinth) do
    {
      'fields' => [
        { '001' => '123456' },
        { '965' => { 'subfields' => [{ 'a' => value_965_hyacinth }] } }
      ]
    }
  end
  let(:marc_record_without_965hyacinth) do
    {
      'fields' => [
        { '001' => '789012' },
        { '965' => { 'subfields' => [{ 'a' => 'different_value' }] } }
      ]
    }
  end

  let(:source_record_with_965hyacinth) do
    { 'parsedRecord' => { 'content' => marc_record_with_965hyacinth } }
  end

  let(:source_record_without_965hyacinth) do
    { 'parsedRecord' => { 'content' => marc_record_without_965hyacinth } }
  end

  before do
    allow(FolioSync::Folio::Client).to receive(:instance).and_return(folio_client)
    allow(FolioSync::Folio::Reader).to receive(:new).and_return(folio_reader)
    allow(Rails.configuration).to receive(:folio_to_hyacinth).and_return(folio_to_hyacinth_config)
    allow(Rails).to receive(:logger).and_return(Logger.new(nil))
  end

  describe '#initialize' do
    it 'can be instantiated' do
      expect(instance).to be_a(described_class)
    end

    it 'initializes with the correct dependencies' do
      expect(instance.instance_variable_get(:@folio_client)).to eq(folio_client)
      expect(instance.instance_variable_get(:@folio_reader)).to eq(folio_reader)
      expect(instance.instance_variable_get(:@downloading_errors)).to eq([])
    end
  end

  describe '#download_965hyacinth_marc_records' do
    let(:last_x_hours) { 24 }
    let(:modified_since) { Time.now.utc - (3600 * last_x_hours) }

    before do
      allow(Time).to receive(:now).and_return(Time.parse('2025-01-01 12:00:00 UTC'))
      allow(folio_client).to receive(:find_source_marc_records).and_yield(marc_record_with_965hyacinth)
      allow(instance).to receive(:save_marc_record_to_file)
    end

    it 'calculates modified_since correctly' do
      expect(folio_client).to receive(:find_source_marc_records).with(
        modified_since: '2024-12-31T12:00:00Z',
        with_965_value: value_965_hyacinth
      )
      instance.download_965hyacinth_marc_records(last_x_hours)
    end


    context 'when last_x_hours is nil' do
      it 'downloads all records without modified_since filter' do
        expect(folio_client).to receive(:find_source_marc_records).with(
          modified_since: nil,
          with_965_value: value_965_hyacinth
        )
        instance.download_965hyacinth_marc_records(nil)
      end

      it 'logs that all records are being downloaded' do
        expect(Rails.logger).to receive(:info).with(/Downloading MARC with 965hyacinth \(all records\)/)
        instance.download_965hyacinth_marc_records(nil)
        expect(folio_client).to have_received(:find_source_marc_records).with(modified_since: nil, with_965_value: value_965_hyacinth)
        expect(instance).to have_received(:save_marc_record_to_file).with(marc_record_with_965hyacinth).once
        expect(instance).not_to have_received(:save_marc_record_to_file).with(marc_record_without_965hyacinth)
      end
    end

    context 'when record has 965hyacinth field' do
      it 'saves the MARC record to file' do
        expect(instance).to receive(:save_marc_record_to_file).with(marc_record_with_965hyacinth)
        instance.download_965hyacinth_marc_records(last_x_hours)
      end
    end

    context 'when record does not have 965hyacinth field' do
      before do
        allow(folio_client).to receive(:find_source_marc_records).and_yield(marc_record_without_965hyacinth)
      end

      it 'does not save the record' do
        expect(instance).not_to receive(:save_marc_record_to_file)
        instance.download_965hyacinth_marc_records(last_x_hours)
      end
    end

    context 'when saving fails' do
      before do
        allow(instance).to receive(:save_marc_record_to_file).and_raise(StandardError.new('File write error'))
      end

      it 'captures the error' do
        instance.download_965hyacinth_marc_records(last_x_hours)
        expect(instance.downloading_errors).to include(/Failed to save MARC record 123456: File write error/)
      end

      it 'continues processing other records' do
        allow(folio_client).to receive(:find_source_marc_records).and_yield(marc_record_with_965hyacinth).and_yield(marc_record_with_965hyacinth)
        instance.download_965hyacinth_marc_records(last_x_hours)
        expect(instance.downloading_errors.length).to eq(2)
      end
    end
  end

  describe '#has_965hyacinth_field?' do
    context 'when record has 965$a with value 965hyacinth' do
      it 'returns true' do
        expect(instance.has_965hyacinth_field?(marc_record_with_965hyacinth)).to be true
      end
    end

    context 'when record has no 965 field' do
      it 'returns false' do
        expect(instance.has_965hyacinth_field?(marc_record_without_965hyacinth)).to be false
      end
    end

    context 'when record has 965 field but not in $a subfield' do
      let(:marc_record_wrong_subfield) do
        {
          'fields' => [
            {
              '965' => {
                'subfields' => [
                  { 'b' => value_965_hyacinth }
                ]
              }
            }
          ]
        }
      end

      it 'returns false' do
        expect(instance.has_965hyacinth_field?(marc_record_wrong_subfield)).to be false
      end
    end

    context 'when record has 965$a with different value' do
      let(:marc_record_wrong_value) do
        {
          'fields' => [
            {
              '965' => {
                'subfields' => [
                  { 'a' => 'different_value' }
                ]
              }
            }
          ]
        }
      end

      it 'returns false' do
        expect(instance.has_965hyacinth_field?(marc_record_wrong_value)).to be false
      end
    end

    context 'when record has multiple 965 fields' do
      let(:marc_record_multiple_965) do
        {
          'fields' => [
            {
              '965' => {
                'subfields' => [
                  { 'a' => 'other_value' }
                ]
              }
            },
            {
              '965' => {
                'subfields' => [
                  { 'a' => value_965_hyacinth }
                ]
              }
            }
          ]
        }
      end

      it 'returns true if any 965$a has the correct value' do
        expect(instance.has_965hyacinth_field?(marc_record_multiple_965)).to be true
      end
    end
  end

  describe '#save_marc_record_to_file' do
    let(:marc_record) { instance_double(MARC::Record) }
    let(:filename) { '123456' }
    let(:marc_binary) { 'binary_marc_data' }

    before do
      allow(MARC::Record).to receive(:new_from_hash).with(marc_record_with_965hyacinth).and_return(marc_record)
      allow(marc_record).to receive(:to_marc).and_return(marc_binary)
      allow(File).to receive(:binwrite)
      allow(File).to receive(:join).and_return(folio_to_hyacinth_config[:download_directory])
    end

    it 'extracts the filename from 001 field' do
      expect(instance).to receive(:extract_id).with(marc_record_with_965hyacinth).and_return(filename)
      instance.save_marc_record_to_file(marc_record_with_965hyacinth)
    end

    it 'creates MARC record from hash' do
      expect(MARC::Record).to receive(:new_from_hash).with(marc_record_with_965hyacinth)
      instance.save_marc_record_to_file(marc_record_with_965hyacinth)
    end

    it 'writes the MARC binary to file' do
      expect(File).to receive(:binwrite).with(folio_to_hyacinth_config[:download_directory], marc_binary)
      instance.save_marc_record_to_file(marc_record_with_965hyacinth)
    end

    context 'when 001 field is missing' do
      let(:marc_record_no_001) do
        {
          'fields' => [
            {
              '965' => {
                'subfields' => [
                  { 'a' => value_965_hyacinth }
                ]
              }
            }
          ]
        }
      end

      it 'raises Missing001Field exception' do
        expect {
          instance.save_marc_record_to_file(marc_record_no_001)
        }.to raise_error(FolioSync::Exceptions::Missing001Field, 'MARC record is missing required 001 field')
      end
    end
  end

  describe '#download_single_965hyacinth_marc_record' do
    let(:folio_hrid) { 'test_hrid' }
    before do
      allow(folio_client).to receive(:find_source_record)
        .with(instance_record_hrid: folio_hrid)
        .and_return(source_record_with_965hyacinth)
      allow(instance).to receive(:save_marc_record_to_file)
    end

    it 'fetches the source record by HRID' do
      expect(folio_client).to receive(:find_source_record).with(instance_record_hrid: folio_hrid)
      instance.download_single_965hyacinth_marc_record(folio_hrid)
    end

    it 'checks for 965hyacinth field' do
      expect(instance).to receive(:has_965hyacinth_field?).with(marc_record_with_965hyacinth).and_call_original
      instance.download_single_965hyacinth_marc_record(folio_hrid)
    end

    it 'saves the MARC record to file' do
      expect(instance).to receive(:save_marc_record_to_file).with(marc_record_with_965hyacinth)
      instance.download_single_965hyacinth_marc_record(folio_hrid)
    end

    context 'when record does not have 965hyacinth field' do
      before do
        allow(folio_client).to receive(:find_source_record)
          .with(instance_record_hrid: folio_hrid)
          .and_return(source_record_without_965hyacinth)
      end

      it 'raises an error' do
        expect {
          instance.download_single_965hyacinth_marc_record(folio_hrid)
        }.to raise_error(/doesn't have a 965 field with subfield \$a value of '965hyacinth'/)
      end
    end

    context 'when source record does not exist' do
      before do
        allow(folio_client).to receive(:find_source_record)
          .with(instance_record_hrid: folio_hrid)
          .and_return(nil)
      end

      it 'raises an error' do
        expect {
          instance.download_single_965hyacinth_marc_record(folio_hrid)
        }.to raise_error(NoMethodError)
      end
    end
  end
end