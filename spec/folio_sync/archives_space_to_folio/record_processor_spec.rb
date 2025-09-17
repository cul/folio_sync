# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FolioSync::ArchivesSpaceToFolio::RecordProcessor do
  include_context 'FolioSync directory setup'

  let(:processor) { described_class.new(instance_key) }
  let(:record) { FactoryBot.create(:aspace_to_folio_record, :suppressed_record, :with_folio_data) }

  describe '#process_record' do
    context 'when processing succeeds' do
      let(:marc_record) { MARC::Record.new }

      before do
        FileUtils.mkdir_p(File.dirname(record.prepared_folio_marc_path))

        # Create a sample MARC record and write it to the expected file
        marc_record.append(MARC::ControlField.new('001', 'test123'))
        marc_record.append(MARC::DataField.new('245', '0', '0', ['a', 'Test Title']))
        marc_record.append(MARC::DataField.new('049', '0', '0', ['a', 'Test Holding Library']))

        writer = MARC::Writer.new(record.prepared_folio_marc_path)
        writer.write(marc_record)
        writer.close
      end

      it 'returns a hash with marc_record and metadata' do
        result = processor.process_record(record)
        expect(result).to be_a(Hash)
        expect(result[:marc_record]).to be_a(MARC::Record)
        expect(result[:marc_record]['001'].value).to eq('test123')
        expect(result[:metadata]).to eq(
          repository_key: record.repository_key,
          resource_key: record.resource_key,
          hrid: record.folio_hrid,
          suppress_discovery: true,
          holdings_call_number: record.holdings_call_number,
          permanent_location: 'Test Holding Library'
        )
      end

      it 'loads MARC record from prepared file path' do
        result = processor.process_record(record)
        expect(result[:marc_record]).to be_a(MARC::Record)
        expect(result[:marc_record]['245']['a']).to eq('Test Title')
        expect(result[:marc_record]['049']['a']).to eq('Test Holding Library')
      end
    end

    context 'when folio_hrid is nil' do
      let(:marc_record) { MARC::Record.new }

      before do
        allow(record).to receive(:folio_hrid).and_return(nil)

        FileUtils.mkdir_p(File.dirname(record.prepared_folio_marc_path))
        marc_record.append(MARC::ControlField.new('001', 'test123'))
        marc_record.append(MARC::DataField.new('245', '0', '0', ['a', 'Test Title']))
        marc_record.append(MARC::DataField.new('049', '0', '0', ['a', 'Test Holding Library']))

        writer = MARC::Writer.new(record.prepared_folio_marc_path)
        writer.write(marc_record)
        writer.close
      end

      it 'still processes the record correctly' do
        result = processor.process_record(record)
        expect(result).to be_a(Hash)
        expect(result[:marc_record]).to be_a(MARC::Record)
        expect(result[:metadata][:hrid]).to be_nil
      end
    end

    # Skip creating a MARC file, so File.exist? will return false
    # This will cause load_marc_record to raise an exception
    context 'when an error occurs during processing' do
      it 'returns nil and logs the error' do
        expect(Rails.logger).to receive(:error).with(/Error processing record #{record.id}/)
        result = processor.process_record(record)
        expect(result).to be_nil
        expect(processor.processing_errors).not_to be_empty
        error = processor.processing_errors.first
        expect(error.resource_uri).to eq("repositories/#{record.repository_key}/resources/#{record.resource_key}")
        expect(error.message).to match(/Failed to process record/)
      end
    end
  end
end