# frozen_string_literal: true

module HyacinthApi
  module Finders
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
        raise HyacinthApi::Exceptions::ApiError, "Error: Received response '#{e.message}' for Hyacinth search request."
      end
    end
  end
end