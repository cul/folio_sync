# frozen_string_literal: true

class Folio::Client::JobExecutionSummary
  attr_reader :raw_results, :records_processed

  # Creates a new JobExecutionSummary object.  This is a wrapper around the response from a
  # GET "/metadata-provider/jobLogEntries/#{@id}" request for a previously started job execution.
  def initialize(raw_job_log_entries_response, custom_metadata_for_records)
    Rails.logger.debug("Creating JobExecutionSummary with #{raw_job_log_entries_response.length} results")
    @raw_results = raw_job_log_entries_response
    # Sort results by their sourceRecordOrder
    @raw_results.sort_by! { |a| a['sourceRecordOrder'] }
    @records_processed = @raw_results.length
    @custom_metadata_for_records = custom_metadata_for_records
    
    Rails.logger.debug("JobExecutionSummary initialized with #{@records_processed} processed records")
    
    # Log first few results for debugging
    @raw_results.first(3).each_with_index do |result, index|
      Rails.logger.debug("Result #{index}: sourceRecordOrder=#{result['sourceRecordOrder']}, " \
                        "actionStatus=#{result.dig('relatedInstanceInfo', 'actionStatus')}, " \
                        "hridList=#{result.dig('relatedInstanceInfo', 'hridList')}")
    end
  end

  # Iterate over each result
  # @yield [raw_result, custom_metadata, instance_action_status, hrid_list, id_list]
  def each_result
    Rails.logger.debug("Iterating over #{@raw_results.length} results")
    @raw_results.each do |raw_result|
      custom_metadata = @custom_metadata_for_records[raw_result['sourceRecordOrder'].to_i] || {}
      instance_action_status = raw_result.dig('relatedInstanceInfo', 'actionStatus')
      hrid_list = raw_result.dig('relatedInstanceInfo', 'hridList')
      id_list = raw_result.dig('relatedInstanceInfo', 'idList')
      
      Rails.logger.debug("Processing result: order=#{raw_result['sourceRecordOrder']}, " \
                        "status=#{instance_action_status}, hrid=#{hrid_list}, " \
                        "metadata=#{custom_metadata.inspect}")
      
      yield raw_result, custom_metadata, instance_action_status, hrid_list, id_list
    end
  end
end
