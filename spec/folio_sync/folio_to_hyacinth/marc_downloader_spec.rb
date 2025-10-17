# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FolioSync::FolioToHyacinth::MarcDownloader do
  let(:instance) { described_class.new }
  let(:folio_client) { instance_double(FolioSync::Folio::Client) }
  let(:folio_reader) { instance_double(FolioSync::Folio::Reader) }
  let(:config) { { download_directory: '/tmp/downloads' } }
  let(:value_965) { '965hyacinth' }
  
  let(:marc_record_with_965hyacinth) do
    {
      'fields' => [
        { '001' => '123456' },
        { '965' => { 'subfields' => [{ 'a' => '965hyacinth' }] } }
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
    allow(Rails.configuration).to receive(:folio_to_hyacinth).and_return(config)
  end

  describe '#initialize' do
    it 'initializes with the correct dependencies' do
      expect(instance.instance_variable_get(:@folio_client)).to eq(folio_client)
      expect(instance.instance_variable_get(:@folio_reader)).to eq(folio_reader)
      expect(instance.instance_variable_get(:@downloading_errors)).to eq([])
    end
  end

  describe '#download_965hyacinth_marc_records' do
    let(:parsed_records) { [marc_record_with_965hyacinth, marc_record_without_965hyacinth] }

    before do
      allow(folio_client).to receive(:find_source_marc_records) do |_modified_since, _options, &block|
        parsed_records.each { |record| block.call(record) }
      end
      allow(instance).to receive(:save_marc_record_to_file)
      allow(Rails.logger).to receive(:info)
    end

    context 'when last_x_hours is nil' do
      it 'downloads all records without time filter' do
        instance.download_965hyacinth_marc_records(nil)

        expect(Rails.logger).to have_received(:info).with(
          'Downloading MARC with 965hyacinth (all records)'
        )
        expect(folio_client).to have_received(:find_source_marc_records).with(modified_since: nil, with_965_value: value_965)
        expect(instance).to have_received(:save_marc_record_to_file).with(marc_record_with_965hyacinth).once
        expect(instance).not_to have_received(:save_marc_record_to_file).with(marc_record_without_965hyacinth)
      end
    end

    context 'when last_x_hours is specified' do
      let(:last_x_hours) { 24 }
      let(:expected_time) { Time.parse('2024-06-25T10:00:00Z') }

      before do
        allow(Time).to receive(:now).and_return(Time.parse('2024-06-26T10:00:00Z'))
      end

      it 'downloads records modified since the specified time' do
        instance.download_965hyacinth_marc_records(last_x_hours)

        expect(Rails.logger).to have_received(:info).with(
          "Downloading MARC with 965hyacinth modified since: #{expected_time.utc.iso8601}"
        )
        expect(folio_client).to have_received(:find_source_marc_records).with(modified_since: expected_time.utc.iso8601, with_965_value: value_965)
        expect(instance).to have_received(:save_marc_record_to_file).with(marc_record_with_965hyacinth).once
      end
    end
  end

  describe '#has_965hyacinth_field?' do
    context 'when record has 965 field with 965hyacinth value' do
      it 'returns true' do
        expect(instance.has_965hyacinth_field?(marc_record_with_965hyacinth)).to be true
      end
    end

    context 'when record has 965 field but not with 965hyacinth value' do
      it 'returns false' do
        expect(instance.has_965hyacinth_field?(marc_record_without_965hyacinth)).to be false
      end
    end

    context 'when record has no 965 field' do
      let(:marc_record_no_965) do
        {
          'fields' => [
            { '001' => '345678' },
          ]
        }
      end

      it 'returns false' do
        expect(instance.has_965hyacinth_field?(marc_record_no_965)).to be false
      end
    end

    context 'when 965 field has no subfields' do
      let(:marc_record_965_no_subfields) do
        {
          'fields' => [
            { '001' => '456789' },
            { '965' => {} }
          ]
        }
      end

      it 'returns false' do
        expect(instance.has_965hyacinth_field?(marc_record_965_no_subfields)).to be false
      end
    end
  end

  describe '#save_marc_record_to_file' do
    let(:formatted_marc) { double('MARC::Record') }
    let(:expected_file_path) { '/tmp/downloads/123456.mrc' }

    before do
      allow(MARC::Record).to receive(:new_from_hash).with(marc_record_with_965hyacinth).and_return(formatted_marc)
      allow(File).to receive(:binwrite)
      allow(Rails.logger).to receive(:info)
    end

    it 'saves the MARC record to the correct file path' do
      instance.save_marc_record_to_file(marc_record_with_965hyacinth)

      expect(Rails.logger).to have_received(:info).with(
        'Saving MARC record with 001=123456 to /tmp/downloads/123456.mrc'
      )
      expect(MARC::Record).to have_received(:new_from_hash).with(marc_record_with_965hyacinth)
      expect(File).to have_received(:binwrite).with(expected_file_path, formatted_marc)
    end
  end

  describe '#download_single_965hyacinth_marc_record' do
    let(:folio_hrid) { 'test_hrid' }

    context 'when record exists and has 965hyacinth field' do
      before do
        allow(folio_client).to receive(:find_source_record)
          .with(instance_record_hrid: folio_hrid)
          .and_return(source_record_with_965hyacinth)
        allow(instance).to receive(:save_marc_record_to_file)
      end

      it 'downloads and saves the record' do
        instance.download_single_965hyacinth_marc_record(folio_hrid)

        expect(folio_client).to have_received(:find_source_record).with(instance_record_hrid: folio_hrid)
        expect(instance).to have_received(:save_marc_record_to_file).with(marc_record_with_965hyacinth)
      end
    end

    context 'when record exists but does not have 965hyacinth field' do
      before do
        allow(folio_client).to receive(:find_source_record)
          .with(instance_record_hrid: folio_hrid)
          .and_return(source_record_without_965hyacinth)
      end

      it 'raises an exception' do
        expect {
          instance.download_single_965hyacinth_marc_record(folio_hrid)
        }.to raise_error("Source record with HRID #{folio_hrid} doesn't have a 965 field with subfield $a value of '965hyacinth'.")
      end
    end

    context 'when record does not exist' do
      before do
        allow(folio_client).to receive(:find_source_record)
          .with(instance_record_hrid: folio_hrid)
          .and_return(nil)
      end

      it 'raises an exception' do
        expect {
          instance.download_single_965hyacinth_marc_record(folio_hrid)
        }.to raise_error(NoMethodError)
      end
    end
  end
end