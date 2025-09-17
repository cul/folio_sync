# frozen_string_literal: true

require 'csv'

# This task should be run once to fill in missing holdings call numbers in AspaceToFolioRecord records.
namespace :one_time_holdings_call_number_update do
  task run: :environment do
    def resolve_call_number(resource, repo_id, archivesspace_instance_key)
      return [resource['id_0'], resource['id_1'], resource['id_2']].compact.join('.') if archivesspace_instance_key == 'barnard'

      repo_id == 2 ? resource.dig('user_defined', 'string_1') : resource['title']
    end

    FolioSync::Rake::EnvValidator.validate!(
      ['instance_key'],
      'bundle exec rake folio_sync_test:retrieve_resources instance_key=cul'
    )

    instance_key = ENV['instance_key']
    client = FolioSync::ArchivesSpace::Client.new(instance_key)
    csv_file_path = Rails.root.join(
      "tmp/#{instance_key}_updated_db_records_with_holdings_call_number_#{Time.zone.now.strftime('%Y%m%d%H%M%S')}.csv"
    )

    # Get all AspaceToFolioRecord records with missing holdings_call_number
    records_to_update = AspaceToFolioRecord.where(holdings_call_number: [nil, ''], archivesspace_instance_key: instance_key)
    puts "Found #{records_to_update.count} records with missing holdings_call_number."

    # Update each record and log the changes to a CSV file
    CSV.open(csv_file_path, 'w') do |csv|
      csv << ['Resource URI', 'Resolved Call Number']

      records_to_update.each do |record|
        puts "Processing record ID: #{record.id}, Repository Key: #{record.repository_key}, Resource Key: #{record.resource_key}"
        resource_data = client.fetch_resource(record.repository_key, record.resource_key)

        puts "Fetched resource for repo key #{record.repository_key}, resource key #{record.resource_key}, instance key #{instance_key}"

        call_number = resolve_call_number(resource_data, record.repository_key, instance_key)
        puts "Resolved call number: #{call_number} for resource #{resource_data['uri']}"
        record.update(holdings_call_number: call_number.strip)
        csv << [resource_data['uri'], call_number]
      end
    end
  end
end
