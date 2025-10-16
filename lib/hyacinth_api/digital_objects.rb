# frozen_string_literal: true

module HyacinthApi
  module DigitalObjects
    def update_existing_record(pid, digital_object_data, publish: false)
      Retriable.retriable(
        on: [Faraday::ConnectionFailed, Faraday::TimeoutError],
        tries: 2,
        base_interval: 1
      ) do
        # For testing, we'll change the title before sending the update
        digital_object_data['dynamic_field_data']['title'] = [{ "title_sort_portion" => 'Test - Changed title' }]
        puts "Sending data: #{digital_object_data}"

        response = put("/digital_objects/#{pid}.json", {
          'digital_object_data_json' => JSON.generate(digital_object_data.merge({ publish: publish.to_s}))
        })
        puts "Response from Hyacinth when updating record #{pid}: #{response.inspect}"

        unless response['success']
          raise HyacinthApi::Exceptions::UpdateError,
                "Failed to update record #{pid}: #{response['errors']}"
        end

        response
      end
    rescue Faraday::Error => e
      raise HyacinthApi::Exceptions::ApiError, "Hyacinth API error for record #{pid}: #{e.message}"
    rescue JSON::ParserError => e
      raise HyacinthApi::Exceptions::ParseError, "Invalid JSON response for record #{pid}: #{e.message}"
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
end
