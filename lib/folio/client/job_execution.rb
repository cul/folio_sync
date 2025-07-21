# frozen_string_literal: true

# rubocop:disable Metrics/MethodLength

# A FOLIO job execution (part of the FOLIO Data Import feature)
# For more information about Data Import, follow the link below:
# https://github.com/folio-org/mod-source-record-manager/tree/master?tab=readme-ov-file#data-import-workflow
class Folio::Client::JobExecution
  JOB_EXECUTION_START_TIMEOUT = 120
  JOB_EXECUTION_INACTIVITY_TIMEOUT = 15

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
  # @param [Integer] job_log_entry_batch_size The internal batch size to use when retrieving job log entries from the
  #                                           data import API endpoint.  A bigger value results in fewer requests.
  #                                           A smaller number results in faster requests.
  def initialize(folio_client, job_profile_uuid, data_type, number_of_expected_records, batch_size, job_log_entry_batch_size)
    @client = folio_client
    @number_of_expected_records = number_of_expected_records
    @number_of_records_flushed_so_far = 0
    @has_started = false
    @batch_size = batch_size
    @job_log_entry_batch_size = job_log_entry_batch_size
    @unflushed_record_batch = []
    @custom_metadata_for_records = []
    @job_profile_info_dto = { 'id': job_profile_uuid, 'dataType': data_type }
    @current_user_id = self.current_user_id
    @id = self.create_job_execution
    Rails.logger.info("JobExecution created with ID: #{@id}, expecting #{number_of_expected_records} records")
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
    response['jobExecutions'][0]['id']
  end

  # Performs an API request that adds the job profile to the job execution, which will initiate
  # the creation of a job profile snapshot in FOLIO (which is required for a job execution to run).
  def set_job_profile_to_job_execution
    client.put("/change-manager/jobExecutions/#{@id}/jobProfile", @job_profile_info_dto)
    Rails.logger.debug('Job profile set successfully')
  end

  # Add a single record to the current job execution.  This method can be called multiple times
  # for multiple records.
  def add_record(marc_record, custom_metadata = {})
    Rails.logger.debug("Adding record with metadata: #{custom_metadata.inspect}")
    # Keep track of any custom metadata sent with this record.  Later on, we'll link it to each of the results
    # in the result set returned at the end of the job execution.
    @custom_metadata_for_records[@unflushed_record_batch.length] = custom_metadata
    @unflushed_record_batch << marc_record
    Rails.logger.debug("Unflushed batch size: #{@unflushed_record_batch.length}/#{@batch_size}")
    flush_unflushed_record_batch if @unflushed_record_batch.length == @batch_size
  end

  # Adds the given MARC records to the job execution (but does not start )
  # @param [Array<MARC::Record>] An array of MARC::Record objects.
  def flush_unflushed_record_batch(is_last_batch: false)
    raise "Cannot add more MARC records to a #{self.class.name} that has already started!" if @has_started

    Rails.logger.info("Flushing batch of #{@unflushed_record_batch.length} records (is_last_batch: #{is_last_batch})")

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

    Rails.logger.debug("Flushing with recordsMetadata: #{raw_records_dto[:recordsMetadata].to_json}")
    # Flush the batch
    client.post("/change-manager/jobExecutions/#{@id}/records", raw_records_dto)
    @number_of_records_flushed_so_far = counter_value_for_batch
    Rails.logger.info("Flushed #{@unflushed_record_batch.length} records. Total flushed: #{@number_of_records_flushed_so_far}")

    # Now that we've flushed this batch, clear @unflushed_record_batch
    @unflushed_record_batch = []
  end

  # Flush any remaining records and tell FOLIO to begin processing the records submitted for this job execution.
  def start
    Rails.logger.info("Starting job execution #{@id}")
    # Flush any remaining records
    self.flush_unflushed_record_batch unless @unflushed_record_batch.empty?

    if @number_of_records_flushed_so_far != @number_of_expected_records
      raise "Cannot start #{self.class.name}. Number of records added so far (#{@number_of_records_flushed_so_far}) "\
            "does not equal number of expected records (#{@number_of_expected_records})."
    end

    # Flush final empty batch with `is_last_batch: true` argument, which only serves to indicate that we are done
    # sending batches. (This practice is recommended by EBSCO.)
    Rails.logger.info('Sending final empty batch to signal completion')
    self.flush_unflushed_record_batch(is_last_batch: true)

    @has_started = true
    Rails.logger.info("Job execution #{@id} started successfully")
  end

  def folio_acknolwedged_job_has_started?
    client.get("/change-manager/jobExecutions/#{@id}").dig('progress', 'current').positive?
  end

  def fetch_folio_job_execution_details
    client.get("/change-manager/jobExecutions/#{@id}")
  end

  # Blocks until the job execution is complete, and then returns a Folio::Client::JobExecutionSummary.
  # @return A Folio::Client::JobExecutionSummary object containing information about the job once it is complete.
  def wait_until_complete
    start_time = Time.current
    wait_for_job_to_start(start_time)
    wait_for_job_to_complete(start_time)
    create_job_execution_summary
  end

  # Waits for the FOLIO job to acknowledge that it has started processing records
  def wait_for_job_to_start(start_time)
    Rails.logger.info("Waiting for job execution #{@id} to start. Expecting #{@number_of_expected_records} records.")

    loop do
      sleep 2
      break if folio_acknolwedged_job_has_started?

      time_since_start = Time.current - start_time
      next unless time_since_start > JOB_EXECUTION_START_TIMEOUT

      raise FolioSync::Exceptions::JobExecutionStartTimeoutError,
            "Job #{@id} has taken too long to start.  #{time_since_start} seconds have passed and no records "\
            'have been processed.'
    end

    Rails.logger.info("Job execution #{@id} has started.  It took #{Time.current - start_time} seconds to start.")
  end

  # Waits for the job to complete while monitoring for inactivity
  def wait_for_job_to_complete(start_time)
    Rails.logger.info("Waiting for job execution #{@id} to complete. Expecting #{@number_of_expected_records} records.")

    last_activity_time = Time.current
    num_records_processed = 0

    loop do
      sleep 2
      folio_job_execution_details = fetch_folio_job_execution_details
      break if folio_job_execution_details['status'] == 'COMMITTED' # This indicates that the job is done

      latest_num_records_processed = folio_job_execution_details.dig('progress', 'current') || 0
      if num_records_processed != latest_num_records_processed
        num_records_processed = latest_num_records_processed
        last_activity_time = Time.current
      end

      Rails.logger.debug(
        "Current num_records_processed for job execution #{@id}: "\
        "#{num_records_processed}. Expecting #{@number_of_expected_records} records."
      )

      time_since_last_activity = Time.current - last_activity_time
      next unless time_since_last_activity > JOB_EXECUTION_INACTIVITY_TIMEOUT

      raise FolioSync::Exceptions::JobExecutionInactivityTimeoutError,
            "Job #{@id} has been inactive for too long. Timed out after #{time_since_last_activity} "\
            "seconds of inactivity.  Number of records processed: #{num_records_processed} "\
            "out of #{@number_of_expected_records} expected."
    end

    Rails.logger.info("Job execution #{@id} has finished.  It took #{Time.current - start_time} seconds to run.")
  end

  # Creates and returns a JobExecutionSummary with detailed logging
  def create_job_execution_summary
    entries = fetch_aggregated_job_execution_entries

    Rails.logger.debug("Number of entries in response: #{entries.length}")

    # Log detailed information about each entry
    entries.each_with_index do |entry, index|
      Rails.logger.debug("Entry #{index}: sourceRecordOrder=#{entry['sourceRecordOrder']}, " \
                        "sourceRecordActionStatus=#{entry['sourceRecordActionStatus']}, " \
                        "has sourceRecordActionStatus key=#{entry.key?('sourceRecordActionStatus')}, " \
                        "error=#{entry['error']}, " \
                        "relatedInstanceInfo.actionStatus=#{entry.dig('relatedInstanceInfo', 'actionStatus')}")
    end

    Rails.logger.info("Entries count: #{entries.length}/#{@number_of_expected_records}")
    Rails.logger.info("Creating JobExecutionSummary with #{entries.length} entries")

    Folio::Client::JobExecutionSummary.new(entries, @custom_metadata_for_records)
  end

  # We might have a very high number of entries in a job.  Could be on the scale of 5000+.
  # We probably don't want to retrieve 5000 JSON objects in a single request, since FOLIO
  # sometimes locks up with really large JSON responses, so we'll retrieve the entries in
  # paginated batches.  If we fail to retrieve one of the pages of results, we'll retry retrieval.
  def fetch_aggregated_job_execution_entries
    entries = []
    offset = 0
    limit = @job_log_entry_batch_size

    loop do
      Retriable.retriable(on: Faraday::Error, tries: 3, base_interval: 1) do
        Rails.logger.debug(
          '(within retriable block) fetch_aggregated_job_execution_entries is retrieving '\
          "results with offset #{offset} and limit #{limit}..."
        )
        job_execution_status_response = client.get(
          "/metadata-provider/jobLogEntries/#{@id}", { limit: limit, offset: offset }
        )
        entries.concat(job_execution_status_response['entries'])
      end

      offset += limit
      break if offset >= @number_of_expected_records
    end

    Rails.logger.debug("fetch_aggregated_job_execution_entries is returning #{entries.length} entries")
    entries
  end
end

# rubocop:enable Metrics/MethodLength
