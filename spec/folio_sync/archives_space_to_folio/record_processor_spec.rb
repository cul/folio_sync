# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FolioSync::ArchivesSpaceToFolio::RecordProcessor do
  include_context 'FolioSync directory setup'

  let(:processor) { described_class.new(instance_key) }
  let(:folio_hrid) { 'f123' }
  let(:record) { FactoryBot.create(:aspace_to_folio_record, :suppressed_record, :with_folio_data) }
  let(:base_dir) { 'tmp/test/downloaded_files' }
  let(:aspace_marc_path) { File.join(base_dir, record.archivesspace_marc_xml_path) }
  let(:folio_marc_path) { File.join(base_dir, record.folio_marc_xml_path) }

  describe '#process_record' do
    context 'when processing succeeds' do
      let(:fake_marc) { double('Marc::Record') }
      let(:processed_record) { marc_record.enhance_marc_record! }

      it 'returns a hash with marc_record and metadata' do
        fake_marc = double('MARC::Record')
        enhancer = double('MarcRecordEnhancer')
        allow(FolioSync::ArchivesSpaceToFolio::MarcRecordEnhancer).to receive(:new).with(
          aspace_marc_path,
          folio_marc_path,
          record.folio_hrid,
          instance_key
        ).and_return(enhancer)
        allow(enhancer).to receive(:enhance_marc_record!).and_return(fake_marc)

        result = processor.process_record(record)
        expect(result).to be_a(Hash)
        expect(result[:marc_record]).to eq(fake_marc)
        expect(result[:metadata]).to eq(
          repository_key: record.repository_key,
          resource_key: record.resource_key,
          hrid: record.folio_hrid,
          suppress_discovery: true
        )
      end

      it 'resolves correct MARC file paths' do
        enhancer = double('MarcRecordEnhancer')
        allow(FolioSync::ArchivesSpaceToFolio::MarcRecordEnhancer).to receive(:new).with(
          aspace_marc_path,
          folio_marc_path,
          record.folio_hrid,
          instance_key
        ).and_return(enhancer)
        allow(enhancer).to receive(:enhance_marc_record!).and_return(double('MARC::Record'))

        processor.process_record(record)
      end
    end

    context 'when folio_hrid is nil' do
      before do
        allow(record).to receive(:folio_hrid).and_return(nil)
      end

      it 'passes nil for folio_marc_path' do
        enhancer = double('MarcRecordEnhancer')
        allow(FolioSync::ArchivesSpaceToFolio::MarcRecordEnhancer).to receive(:new).with(
          aspace_marc_path,
          nil,
          nil,
          instance_key
        ).and_return(enhancer)
        allow(enhancer).to receive(:enhance_marc_record!).and_return('marc')

        processor.process_record(record)
      end
    end

    context 'when an error occurs during processing' do
      before do
        allow(FolioSync::ArchivesSpaceToFolio::MarcRecordEnhancer).to receive(:new).and_raise(StandardError, 'Test error')
      end

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