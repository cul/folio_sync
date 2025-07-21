# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FolioSync::ArchivesSpaceToFolio::BatchProcessor do
  let(:instance_key) { 'test_instance' }
  let(:batch_size) { 2 }
  let(:record1) { FactoryBot.build(:aspace_to_folio_record) }
  let(:record2) { FactoryBot.build(:aspace_to_folio_record) }
  let(:records_relation) { double('ActiveRecord::Relation') }
  let(:processed_record1) { double('ProcessedRecord1') }
  let(:processed_record2) { double('ProcessedRecord2') }
  let(:job_execution_summary) { double('JobExecutionSummary') }
  let(:processing_errors) { [] }
  let(:record_processor) { instance_double(FolioSync::ArchivesSpaceToFolio::RecordProcessor, processing_errors: processing_errors) }

  before do
    allow(Rails.configuration).to receive_message_chain(:folio_sync, :dig).and_return(batch_size)
    allow(FolioSync::Folio::Client).to receive(:instance).and_return(double('FolioClient'))
    allow(FolioSync::Folio::Reader).to receive(:new).and_return(double('FolioReader'))
    allow(FolioSync::Folio::Writer).to receive(:new).and_return(double('FolioWriter'))
    allow(FolioSync::ArchivesSpaceToFolio::RecordProcessor).to receive(:new).with(instance_key).and_return(record_processor)
  end

  subject(:batch_processor) { described_class.new(instance_key) }

  describe '#process_records' do
    before do
      # Simulate in_batches yielding batches of records
      allow(records_relation).to receive(:in_batches).with(of: batch_size).and_yield([record1, record2])
      allow(records_relation).to receive(:count).and_return(2)

      allow(record_processor).to receive(:process_record).with(record1).and_return(processed_record1)
      allow(record_processor).to receive(:process_record).with(record2).and_return(processed_record2)

      job_manager = instance_double(::Folio::Client::JobExecutionManager)
      allow(::Folio::Client::JobExecutionManager).to receive(:new).and_return(job_manager)
      allow(job_manager).to receive(:execute_job).with([processed_record1, processed_record2]).and_return(job_execution_summary)

      result_processor = instance_double(FolioSync::ArchivesSpaceToFolio::JobResultProcessor, processing_errors: [])
      allow(FolioSync::ArchivesSpaceToFolio::JobResultProcessor).to receive(:new).and_return(result_processor)
      allow(result_processor).to receive(:process_results).with(job_execution_summary)
    end

    it 'processes records in batches and submits them to FOLIO' do
      expect(records_relation).to receive(:in_batches).with(of: batch_size)
      expect(::Folio::Client::JobExecutionManager).to receive(:new)
      expect(FolioSync::ArchivesSpaceToFolio::JobResultProcessor).to receive(:new)
      expect(record_processor).to receive(:process_record).with(record1).and_return(processed_record1)
      expect(record_processor).to receive(:process_record).with(record2).and_return(processed_record2)

      batch_processor.process_records(records_relation)
      expect(batch_processor.syncing_errors).to eq([])
    end

    context 'when processing errors occur' do
      let(:processing_errors) { [instance_double(FolioSync::Errors::SyncingError)] }

      it 'adds processing errors to syncing_errors' do
        batch_processor.process_records(records_relation)
        expect(batch_processor.syncing_errors).to eq(processing_errors)
      end
    end
  end
end