
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FolioSync::ArchivesSpaceToFolio::JobResultProcessor do
  let(:instance_key) { 'test_instance' }
  let(:folio_reader) { instance_double(FolioSync::Folio::Reader) }
  let(:folio_writer) { instance_double(FolioSync::Folio::Writer) }
  let(:processing_errors) { [] }
  let(:processor) { described_class.new(folio_reader, folio_writer, instance_key) }

  describe '#initialize' do
    it 'can be instantiated with a folio reader, folio writer, and instance key' do
      instance = described_class.new(folio_reader, folio_writer, instance_key)
      expect(instance).to be_a(described_class)
    end
  end

  describe '#process_results' do
    let(:job_execution_summary) { double('JobExecutionSummary') }

    it 'processes each result and updates suppression and database record' do
      allow(job_execution_summary).to receive(:each_result).and_yield(
        nil,
        { repository_key: '123', resource_key: '456789', hrid: 'h1', suppress_discovery: true },
        'CREATED',
        ['h1'],
        ['id1']
      )

      allow(processor).to receive(:update_suppression_status)
      allow(processor).to receive(:update_database_record)

      processor.process_results(job_execution_summary)

      expect(processor).to have_received(:update_suppression_status).with(
        { repository_key: '123', resource_key: '456789', hrid: 'h1', suppress_discovery: true },
        ['id1']
      )
      expect(processor).to have_received(:update_database_record).with(
        { repository_key: '123', resource_key: '456789', hrid: 'h1', suppress_discovery: true },
        'CREATED',
        ['h1']
      )
    end
  end
end