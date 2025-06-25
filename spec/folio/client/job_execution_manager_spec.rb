# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Folio::Client::JobExecutionManager do
  let(:folio_client) { double('FolioSync::Folio::Client') }
  let(:job_profile_uuid) { 'test-job-profile-123' }
  let(:batch_size) { 2 }
  let(:processed_records) do
    [
      { marc_record: MARC::Record.new, metadata: { 'key' => 'value1' } },
      { marc_record: MARC::Record.new, metadata: { 'key' => 'value2' } }
    ]
  end

  describe '#initialize' do
    it 'can be instantiated with a folio client, job profile UUID, and batch size' do
      instance = described_class.new(folio_client, job_profile_uuid, batch_size)
      expect(instance).to be_a(described_class)
    end
  end

  describe '#execute_job' do
    let(:job_execution) { double('JobExecution') }
    let(:manager) { described_class.new(folio_client, job_profile_uuid, batch_size) }

    before do
      allow(folio_client).to receive(:create_job_execution).and_return(job_execution)
      allow(job_execution).to receive(:add_record)
      allow(job_execution).to receive(:start)
      allow(job_execution).to receive(:wait_until_complete).and_return(double(records_processed: 2))
    end

    it 'creates a job execution with correct arguments' do
      manager.execute_job(processed_records)
      expect(folio_client).to have_received(:create_job_execution).with(job_profile_uuid, 'MARC', 2, batch_size)
    end

    it 'adds all processed records to the job execution' do
      manager.execute_job(processed_records)
      expect(job_execution).to have_received(:add_record).with(processed_records[0][:marc_record], processed_records[0][:metadata])
      expect(job_execution).to have_received(:add_record).with(processed_records[1][:marc_record], processed_records[1][:metadata])
    end

    it 'starts the job execution' do
      manager.execute_job(processed_records)
      expect(job_execution).to have_received(:start)
    end

    it 'waits for completion and returns the summary' do
      summary = manager.execute_job(processed_records)
      expect(summary.records_processed).to eq(2)
    end
  end
end