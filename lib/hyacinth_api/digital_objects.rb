# frozen_string_literal: true

module HyacinthApi
  module DigitalObjects
    def update_existing_record(pid, digital_object_data, publish: true)
      Retriable.retriable(
        on: [Faraday::ConnectionFailed, Faraday::TimeoutError],
        tries: 2,
        base_interval: 1
      ) do
        response = put("/digital_objects/#{pid}.json", {
          'digital_object_data_json' => JSON.generate(digital_object_data.merge({ publish: publish.to_s }))
        })

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

    def create_new_record(digital_object_data, publish: false)
      post('/digital_objects.json', {
        'digital_object_data_json' => JSON.generate(digital_object_data.merge({ publish: publish }))
      })
    rescue StandardError => e
      raise "Error creating new record. Details: #{e.message}"
    end
  end
end
