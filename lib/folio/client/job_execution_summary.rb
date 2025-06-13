# frozen_string_literal: true

class Folio::Client::JobExecutionSummary
  attr_reader :raw_results, :records_processed

  # Creates a new JobExecutionSummary object.  This is a wrapper around the response from a
  # GET "/metadata-provider/jobLogEntries/#{@id}" request for a previously started job execution.
  def initialize(raw_job_log_entries_response, custom_metadata_for_records)
    @raw_results = raw_job_log_entries_response
    # Sort results by their sourceRecordOrder
    @raw_results.sort_by! { |a| a['sourceRecordOrder'] }
    @records_processed = @raw_results.length
    @custom_metadata_for_records = custom_metadata_for_records
  end

  # Iterate over each result
  # @yield [raw_result, custom_metadata, instance_action_status, hrid_list]
  def each_result
    @raw_results.each do |raw_result|
      custom_metadata = @custom_metadata_for_records[raw_result['sourceRecordOrder'].to_i] || {}
      instance_action_status = raw_result.dig('relatedInstanceInfo', 'actionStatus')
      hrid_list = raw_result.dig('relatedInstanceInfo', 'hridList')
      yield raw_result, custom_metadata, instance_action_status, hrid_list
    end
  end
end
