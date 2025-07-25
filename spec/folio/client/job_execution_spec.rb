# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Folio::Client::JobExecution do
  let(:folio_client) { double('FolioSync::Folio::Client') }
  let(:job_profile_uuid) { 'test-job-profile-123' }
  let(:data_type) { 'MARC' }
  let(:number_of_expected_records) { 3 }
  let(:batch_size) { 2 }
  let(:job_log_entry_batch_size) { 3 }
  let(:user_id) { 'user-456' }
  let(:job_execution_id) { 'job-789' }
  let(:marc_record) { double('MARC::Record', to_marc: 'marc-content') }

  before do
    allow(folio_client).to receive(:get)
      .with('/bl-users/_self')
      .and_return({ 'user' => { 'id' => user_id } })

    allow(folio_client).to receive(:post)
      .with('/change-manager/jobExecutions', any_args)
      .and_return({ 'jobExecutions' => [{ 'id' => job_execution_id }] })

    allow(folio_client).to receive(:put)
      .with("/change-manager/jobExecutions/#{job_execution_id}/jobProfile", any_args)
      .and_return(nil)

    allow(folio_client).to receive(:post)
      .with("/change-manager/jobExecutions/#{job_execution_id}/records", any_args)
      .and_return(nil)
  end

  describe '#initialize' do
    it 'creates a new job execution with correct attributes' do
      job_execution = described_class.new(
        folio_client, job_profile_uuid, data_type, number_of_expected_records, batch_size, job_log_entry_batch_size
      )

      expect(job_execution.client).to eq(folio_client)
      expect(job_execution.id).to eq(job_execution_id)
      expect(job_execution.number_of_expected_records).to eq(number_of_expected_records)
      expect(job_execution.has_started).to be false
    end

    it 'calls the FOLIO API to create job execution' do
      expect(folio_client).to receive(:post)
        .with('/change-manager/jobExecutions', any_args)
        .and_return({ 'jobExecutions' => [{ 'id' => job_execution_id }] })

      described_class.new(
        folio_client, job_profile_uuid, data_type, number_of_expected_records, batch_size, job_log_entry_batch_size
      )
    end

    it 'sets the job profile on the job execution' do
      expect(folio_client).to receive(:put)
        .with("/change-manager/jobExecutions/#{job_execution_id}/jobProfile", any_args)

      described_class.new(
        folio_client, job_profile_uuid, data_type, number_of_expected_records, batch_size, job_log_entry_batch_size
      )
    end
  end

  describe '#add_record' do
    let(:job_execution) do
      described_class.new(
        folio_client, job_profile_uuid, data_type, number_of_expected_records, batch_size, job_log_entry_batch_size
      )
    end

    it 'adds a record to the batch' do
      # Should not call the API yet (batch_size is 2, we're adding 1)
      expect(folio_client).not_to receive(:post).with(
        "/change-manager/jobExecutions/#{job_execution_id}/records", any_args
      )

      job_execution.add_record(marc_record)
    end

    it 'flushes the batch when batch size is reached' do
      # First record - no flush
      job_execution.add_record(marc_record)

      # Second record - should trigger flush
      expect(folio_client).to receive(:post).with(
        "/change-manager/jobExecutions/#{job_execution_id}/records", any_args
      )

      job_execution.add_record(marc_record)
    end

    it 'stores custom metadata for records' do
      custom_metadata = { source: 'test' }

      job_execution.add_record(marc_record, custom_metadata)
      expect { job_execution.add_record(marc_record) }.not_to raise_error
    end
  end

  describe '#start' do
    let(:job_execution) do
      described_class.new(
        folio_client, job_profile_uuid, data_type, number_of_expected_records, batch_size, job_log_entry_batch_size
      )
    end

    context 'when correct number of records added' do
      before do
        # Add exactly the expected number of records
        number_of_expected_records.times { job_execution.add_record(marc_record) }
      end

      it 'marks the job as started' do
        job_execution.start
        expect(job_execution.has_started).to be true
      end

      it 'flushes any remaining records' do
        # We have 3 records, batch size 2, so 1 record should be left to flush
        expect(folio_client).to receive(:post).with(
          "/change-manager/jobExecutions/#{job_execution_id}/records", any_args
        ).at_least(:once)

        job_execution.start
      end

      it 'sends final empty batch to signal completion' do
        expect(folio_client).to receive(:post).with(
          "/change-manager/jobExecutions/#{job_execution_id}/records", any_args
        ).at_least(:once)

        job_execution.start
      end
    end

    context 'when incorrect number of records added' do
      it 'raises an error if not enough records added' do
        # Add fewer records than expected
        job_execution.add_record(marc_record)

        expect { job_execution.start }.to raise_error(
          RuntimeError,
          /Number of records added so far \(1\) does not equal number of expected records \(3\)/
        )
      end
    end

    context 'when job already started' do
      it 'prevents adding more records after start when batch size is reached' do
        number_of_expected_records.times { job_execution.add_record(marc_record) }
        job_execution.start

        # Add one record (won't flush yet)
        job_execution.add_record(marc_record)

        # Add second record - this should trigger flush and raise the error
        expect { job_execution.add_record(marc_record) }.to raise_error(
          RuntimeError,
          /Cannot add more MARC records to a #{described_class.name} that has already started!/
        )
      end
    end
  end

  describe '#wait_until_complete' do
    let(:job_execution) do
      described_class.new(
        folio_client, job_profile_uuid, data_type, number_of_expected_records, batch_size, job_log_entry_batch_size
      )
    end

    before do
      # Mock Time.current to control timing
      allow(job_execution).to receive(:sleep)
      allow(Time).to receive(:current).and_return(Time.now)

      stub_const('Folio::Client::JobExecutionSummary', Class.new do
        def initialize(processed_records, custom_metadata)
          @processed_records = processed_records
          @custom_metadata = custom_metadata
        end
      end)
    end

    it 'waits for job to start, complete, and returns summary' do
      # Mock job starting
      allow(folio_client).to receive(:get)
        .with("/change-manager/jobExecutions/#{job_execution_id}")
        .and_return({ 'progress' => { 'current' => 1 }, 'status' => 'COMMITTED' })

      # Mock job log entries
      allow(folio_client).to receive(:get)
        .with("/metadata-provider/jobLogEntries/#{job_execution_id}", { limit: 3, offset: 0  })
        .and_return({
          'entries' => [
            { 'sourceRecordOrder' => 0, 'sourceRecordActionStatus' => 'CREATED' },
            { 'sourceRecordOrder' => 1, 'sourceRecordActionStatus' => 'UPDATED' },
            { 'sourceRecordOrder' => 2, 'sourceRecordActionStatus' => 'CREATED' }
          ]
        })

      summary = job_execution.wait_until_complete
      expect(summary).to be_an_instance_of(Folio::Client::JobExecutionSummary)
    end

    it 'calls the three main steps in order' do
      expect(job_execution).to receive(:wait_for_job_to_start).ordered
      expect(job_execution).to receive(:wait_for_job_to_complete).ordered
      expect(job_execution).to receive(:create_job_execution_summary).ordered.and_return(double)

      job_execution.wait_until_complete
    end

    it 'waits for job to start then complete processing all records' do
      call_count = 0
      
      # Mock the job execution status checks
      allow(folio_client).to receive(:get)
        .with("/change-manager/jobExecutions/#{job_execution_id}") do
        call_count += 1
        case call_count
        when 1
          # First call - job hasn't started yet
          { 'progress' => { 'current' => 0 }, 'status' => 'NEW' }
        when 2
          # Second call - job has started, one record processed
          { 'progress' => { 'current' => 1 }, 'status' => 'PROCESSING_IN_PROGRESS' }
        when 3
          # Third call - two records processed
          { 'progress' => { 'current' => 2 }, 'status' => 'PROCESSING_IN_PROGRESS' }
        else
          # Final call - job completed
          { 'progress' => { 'current' => 3 }, 'status' => 'COMMITTED' }
        end
      end

      allow(folio_client).to receive(:get)
        .with("/metadata-provider/jobLogEntries/#{job_execution_id}", { limit: 3, offset: 0 })
        .and_return({
          'entries' => [
            { 'sourceRecordOrder' => 0, 'sourceRecordActionStatus' => 'CREATED' },
            { 'sourceRecordOrder' => 1, 'sourceRecordActionStatus' => 'UPDATED' },
            { 'sourceRecordOrder' => 2, 'sourceRecordActionStatus' => 'CREATED' }
          ]
        })

      summary = job_execution.wait_until_complete
      expect(summary).to be_an_instance_of(Folio::Client::JobExecutionSummary)
      expect(call_count).to be >= 2
    end
  end
end
