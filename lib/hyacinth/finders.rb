# frozen_string_literal: true

module Hyacinth::Finders
  def find_by_identifier(identifier, additional_search_params = {})
    search({
      per_page: 999_999, # high limit so we find all records with the given identifier
      search_field: 'search_identifier_sim',
      q: identifier
    }.merge(additional_search_params))
  end

  def find_by_pid(pid)
    results = search({
      per_page: 1,
      search_field: 'pid',
      q: pid
    })
    results.length == 1 ? results.first : nil
  end

  def search(search_params = {})
    post_params = { search: search_params }

    begin
      results = post('/digital_objects/search.json', post_params)
      results['results'].map { |result| JSON.parse(result['digital_object_data_ts']) }
    rescue Faraday::Error => e
      raise "Error: Received response '#{e.message}' for Hyacinth search request."
    end
  end

  def update_existing_record(pid, digital_object_data, publish: false)
    Retriable.retriable(
      on: [Faraday::ConnectionFailed, Faraday::TimeoutError],
      tries: 2,
      base_interval: 1
    ) do
      response = put("/digital_objects/#{pid}.json", {
        'digital_object_data_json' => JSON.generate(digital_object_data.merge({ publish: publish.to_s, project: { string_key: 'test' } }))
      })
      puts "Response from Hyacinth when updating record #{pid}: #{response.inspect}"

      unless json_response['success']
        raise HyacinthApiClient::Exceptions::UpdateError,
              "Failed to update record #{pid}: #{json_response['errors']}"
      end

      json_response
    end
  rescue Faraday::Error => e
    raise HyacinthApiClient::Exceptions::ApiError, "Hyacinth API error for record #{pid}: #{e.message}"
  rescue JSON::ParserError => e
    raise HyacinthApiClient::Exceptions::ParseError, "Invalid JSON response for record #{pid}: #{e.message}"
  end

  def create_new_record(hrid, publish: false)
    object_data = minimal_data_for_record

    # TODO: Move to a class responsible for building digital object data
    object_data['identifiers'] << "clio#{hrid}"

    post('/digital_objects.json', {
      'digital_object_data_json' => JSON.generate(object_data.merge({ publish: publish }))
    })
  rescue StandardError => e
    raise "Error creating new record. Details: #{e.message}"
  end

  # TODO: Move to a class responsible for building digital object data
  def minimal_data_for_record
    {
      'project' => { "string_key": 'academic_commons' }, # Required! Will be derived from 965$a fields
      'digital_object_type' => { 'string_key' => 'item' },
      'dynamic_field_data' => {
        "title": [
          {
            "title_sort_portion": 'Test Record'
          }
        ]
      },
      'identifiers' => []
    }
  end
end
