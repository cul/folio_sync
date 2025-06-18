# frozen_string_literal: true

# rubocop:disable Metrics/MethodLength

# A FOLIO job execution (part of the FOLIO Data Import feature)
# For more information about Data Import, follow the link below:
# https://github.com/folio-org/mod-source-record-manager/tree/master?tab=readme-ov-file#data-import-workflow
class Folio::Client::JobExecution
  attr_reader :client, :id, :has_started, :number_of_expected_records

  # Creates a new JobExecution.  Note that the creation of this object involves multiple API calls to FOLIO.
  # @param [FolioApiClient] A FolioApiClient object.
  # @param [String] job_profile_uuid The uuid of a job profile that has been created in your FOLIO tenant.
  # @param [String] data_type The data type o this job exeution.  For our purposes, this is usually 'MARC'.
  #                           For a list of all allowed data_type values, see FOLIO API documentation for the
  #                           `POST /change-manager/jobExecutions` endpoint.
  # @param [Integer] number_of_expected_records The number of records you expect to add to this job.  This number needs
  #                                               to be known in advance of starting the job because it is required by
  #                                               the FOLIO Data Import API.  If the number of added records does not
  #                                               equal this number when you attempt to start the JobExecution, an error
  #                                               will be raised.
  # @param [Integer] batch_size The internal batch size to use when sending records to the data import API endpoint
  #                             A bigger value results in fewer requests.  A smaller number results in faster requests.
  #                             The batch_size is not realted to the total number of records you want to import in a
  #                             single job execution.
  def initialize(folio_client, job_profile_uuid, data_type, number_of_expected_records, batch_size)
    @client = folio_client
    @number_of_expected_records = number_of_expected_records
    @number_of_records_flushed_so_far = 0
    @has_started = false
    @batch_size = batch_size
    @unflushed_record_batch = []
    @custom_metadata_for_records = []
    @job_profile_info_dto = { 'id': job_profile_uuid, 'dataType': data_type }
    @current_user_id = self.current_user_id
    @id = self.create_job_execution
    self.set_job_profile_to_job_execution
  end

  def current_user_id
    client.get('/bl-users/_self')['user']['id']
  end

  def create_job_execution
    init_job_executions_request_dto = {
      sourceType: 'ONLINE', # Source type is always 'ONLINE'
      userId: @current_user_id,
      jobProfileInfo: @job_profile_info_dto
    }
    response = client.post('/change-manager/jobExecutions', init_job_executions_request_dto)
    puts "Created job execution with id: #{response['jobExecutions'][0]['id']}"
    response['jobExecutions'][0]['id']
  end

  # Performs an API request that adds the job profile to the job execution, which will initiate
  # the creation of a job profile snapshot in FOLIO (which is required for a job execution to run).
  def set_job_profile_to_job_execution
    client.put("/change-manager/jobExecutions/#{@id}/jobProfile", @job_profile_info_dto)
  end

  # Add a single record to the current job execution.  This method can be called multiple times
  # for multiple records.
  def add_record(marc_record, custom_metadata = {})
    # Keep track of any custom metadata sent with this record.  Later on, we'll link it to each of the results
    # in the result set returned at the end of the job execution.
    @custom_metadata_for_records[@unflushed_record_batch.length] = custom_metadata
    @unflushed_record_batch << marc_record
    flush_unflushed_record_batch if @unflushed_record_batch.length == @batch_size
  end

  # Adds the given MARC records to the job execution (but does not start )
  # @param [Array<MARC::Record>] An array of MARC::Record objects.
  def flush_unflushed_record_batch(is_last_batch: false)
    raise "Cannot add more MARC records to a #{self.class.name} that has already started!" if @has_started

    counter_value_for_batch = @number_of_records_flushed_so_far + @unflushed_record_batch.length
    raw_records_dto = {
      id: SecureRandom.uuid, # for each chunk we need to have and unique uuid
      recordsMetadata: {
        last: is_last_batch,
        counter: counter_value_for_batch,
        contentType: 'MARC_RAW',
        total: @number_of_expected_records
      },
      initialRecords: @unflushed_record_batch.map.with_index(@number_of_records_flushed_so_far) do |marc_record, i|
        # NOTE: The order we explicitly set below will appear in the job log entries as the "sourceRecordOrder".
        # It is important for us to be able to match the order of the job log entries with the order of the input data.
        # This order is 0-indexed, meaning that the first record in the overall import will have an order value of 0.
        { record: marc_record.to_marc, order: i }
      end
    }

    # Flush the batch
    client.post("/change-manager/jobExecutions/#{@id}/records", raw_records_dto)
    @number_of_records_flushed_so_far = counter_value_for_batch

    # Now that we've flushed this batch, clear @unflushed_record_batch
    @unflushed_record_batch = []
  end

  # Flush any remaining records and tell FOLIO to begin processing the records submitted for this job execution.
  def start
    # Flush any remaining records
    self.flush_unflushed_record_batch unless @unflushed_record_batch.empty?

    if @number_of_records_flushed_so_far != @number_of_expected_records
      raise "Cannot start #{self.class.name}.  Number of records added so far (#{@number_of_records_flushed_so_far}) "\
            "does not equal number of expected records (#{@number_of_expected_records})."
    end

    # Flush final empty batch with `is_last_batch: true` argument, which only serves to indicate that we are done
    # sending batches. (This practice is recommended by EBSCO.)
    self.flush_unflushed_record_batch(is_last_batch: true)

    @has_started = true
  end

  # Blocks until the job execution is complete, and then returns a Folio::Client::JobExecutionSummary.
  # @return A Folio::Client::JobExecutionSummary object containing information about the job once it is complete.
  def wait_until_complete
    puts "Waiting for job execution #{@id} to complete..."
    start_time = Time.current
    processed_records = []
    loop do
      sleep 2

      # Check progress
      job_execution_status_response = client.get("/metadata-provider/jobLogEntries/#{@id}")

      total_records_acknowledged = job_execution_status_response['totalRecords'] || 0

      # If it's been a while and the job still appears to have 0 records, we will
      # assume that something has gone wrong and the job has failed, so we'll break.
      elapsed_time_in_seconds = Time.current - start_time
      break if total_records_acknowledged.zero? && elapsed_time_in_seconds > 10

      # If some of the submitted records have been acknowledged, but not all of them are showing up yet,
      # skip this loop iteration and check again during the next iteration.
      next if total_records_acknowledged < @number_of_expected_records

      # If we made it here, this means that all of the records have been acknowledged.
      # Let's see how many have completed processing.
      processed_records = job_execution_status_response['entries'].select do |entry|
        # sourceRecordActionStatus key is only present when processing is complete
        entry.key?('sourceRecordActionStatus')
      end

      # Break if there are a positive number of records
      # and all of those records have been processed.
      break if processed_records.length == @number_of_expected_records
    end

    Folio::Client::JobExecutionSummary.new(processed_records, @custom_metadata_for_records)
  end
end

# rubocop:enable Metrics/MethodLength
