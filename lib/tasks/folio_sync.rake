# frozen_string_literal: true

namespace :folio_sync do
  namespace :aspace_to_folio do
    def recipients_for(instance_key)
      aspace_instances = Rails.configuration.folio_sync[:aspace_to_folio][:aspace_instances]
      aspace_instances[instance_key.to_sym][:marc_sync_email_addresses]
    end

    desc 'Fetch ArchivesSpace MARC resources and sync to FOLIO'
    task run: :environment do
      FolioSync::Rake::EnvValidator.validate!(
        ['instance_key'],
        'bundle exec rake folio_sync:aspace_to_folio:run instance_key=cul'
      )
      instance_key = ENV['instance_key']

      # Optional environment variables
      modified_since = ENV['modified_since']
      clear_downloads = ENV['clear_downloads'].nil? || ENV['clear_downloads'] == 'true'

      processor = FolioSync::ArchivesSpaceToFolio::FolioSynchronizer.new(instance_key)
      processor.clear_downloads! if clear_downloads

      modified_since_time =
        if modified_since && !modified_since.strip.empty?
          begin
            Integer(modified_since)
          rescue ArgumentError
            puts 'Error: modified_since must be an integer (number of hours).'
            exit 1
          end
        end

      puts 'Fetching MARC resources...'
      processor.fetch_and_sync_aspace_to_folio_records(modified_since_time)

      if FolioSync::Rake::ErrorLogger.any_errors?(processor)
        FolioSync::Rake::ErrorLogger.log_errors_to_console(processor)

        ApplicationMailer.with(
          to: recipients_for(instance_key),
          subject: 'FOLIO Sync Errors',
          fetching_errors: processor.fetching_errors,
          saving_errors: processor.saving_errors,
          downloading_errors: processor.downloading_errors,
          syncing_errors: processor.syncing_errors
        ).folio_sync_error_email.deliver
      else
        puts 'Script completed successfully.'
      end
    end

    desc 'Sync already downloaded resources to FOLIO'
    task sync_exported_resources: :environment do
      FolioSync::Rake::EnvValidator.validate!(
        ['instance_key'],
        'bundle exec rake folio_sync:aspace_to_folio:sync_exported_resources instance_key=cul'
      )

      instance_key = ENV['instance_key']
      puts 'Syncing exported resources...'
      processor = FolioSync::ArchivesSpaceToFolio::FolioSynchronizer.new(instance_key)
      processor.sync_resources_to_folio

      if processor.syncing_errors.any?
        puts 'Errors occurred during syncing:'
        processor.syncing_errors.each do |error|
          puts "Bib ID: #{error.bib_id}"
          puts "Error: #{error.message}"
        end

        ApplicationMailer.with(
          to: recipients_for(instance_key),
          subject: 'FOLIO Sync - Error syncing exported resources',
          syncing_errors: processor.syncing_errors
        ).folio_sync_error_email.deliver
      else
        puts 'Syncing completed successfully.'
      end
    end

    # Add a MARC XML test file to the directory specified in folio_sync.yml
    # Run as:
    # bundle exec rake folio_sync:aspace_to_folio:process_marc_xml instance_key=<instance_key> file_name=<file_name>'
    desc 'Create an enhanced MARC record from a MARC XML file'
    task process_marc_xml: :environment do
      FolioSync::Rake::EnvValidator.validate!(
        ['instance_key', 'file_name'],
        'bundle exec rake folio_sync:aspace_to_folio:process_marc_xml instance_key=instance_name file_name=test.xml'
      )

      instance_key = ENV['instance_key']
      file_name = ENV['file_name']
      base_dir = Rails.configuration.folio_sync[:aspace_to_folio][:marc_download_base_directory]
      file_path = File.join(base_dir, instance_key, file_name)

      enhanced_marc_record = FolioSync::ArchivesSpaceToFolio::MarcRecordEnhancer.new(
        file_path,
        nil, # We don't need to pass a FOLIO MARC record for this example
        nil, # HRID is used only to manipulate controlfield 001
        instance_key
      ).enhance_marc_record!

      puts "Processed MARC record: #{enhanced_marc_record}"
    end

    desc 'Perform a health check on the FOLIO API'
    task folio_health_check: :environment do
      puts 'FOLIO health check response:'
      client = FolioSync::Folio::Client.instance
      puts client.check_health
    end

    desc 'Test the email functionality'
    task email_test: :environment do
      FolioSync::Rake::EnvValidator.validate!(
        ['instance_key'],
        'bundle exec rake folio_sync:aspace_to_folio:email_test instance_key=cul'
      )
      instance_key = ENV['instance_key']

      ApplicationMailer.with(
        to: recipients_for(instance_key),
        subject: 'FOLIO Sync Errors - Test Email',
        downloading_errors: [
          FolioSync::Errors::DownloadingError.new(resource_uri: '/uri-test-1', message: 'Error test 1')
        ],
        fetching_errors: [
          FolioSync::Errors::FetchingError.new(resource_uri: '/uri-test-2', message: 'Error test 2')
        ],
        saving_errors: [
          FolioSync::Errors::SavingError.new(resource_uri: '/uri-test-3', message: 'Error test 3')
        ],
        syncing_errors: [
          FolioSync::Errors::SyncingError.new(resource_uri: '/uri-test-4', message: 'Error test 4'),
          FolioSync::Errors::SyncingError.new(message: 'Error test 5')
        ]
      ).folio_sync_error_email.deliver
    end

    task update_ids: :environment do
      FolioSync::Rake::EnvValidator.validate!(
        ['instance_key', 'repo_id', 'resource_id', 'new_id'],
        'bundle exec rake folio_sync:aspace_to_folio:update_ids instance_key=cul repo_id=1 resource_id=123 new_id=123'
      )
      instance_key = ENV['instance_key']

      if instance_key == 'barnard'
        puts "Temporarily disabling writing to Barnard's ArchivesSpace instance"
        exit(1)
      end

      repo_id = ENV['repo_id']
      resource_id = ENV['resource_id']
      new_id = ENV['new_id']

      aspace_client = FolioSync::ArchivesSpace::Client.new(instance_key)
      aspace_client.update_id_fields(repo_id, resource_id, new_id)
    end

    task update_string_1: :environment do
      FolioSync::Rake::EnvValidator.validate!(
        ['instance_key', 'repo_id', 'resource_id', 'new_string'],
        'bundle exec rake folio_sync:aspace_to_folio:update_string_1 instance_key=cul ' \
        'repo_id=1 resource_id=123 new_string=abc'
      )
      instance_key = ENV['instance_key']

      if instance_key == 'barnard'
        puts "Temporarily disabling writing to Barnard's ArchivesSpace instance"
        exit(1)
      end

      repo_id = ENV['repo_id']
      resource_id = ENV['resource_id']
      new_string = ENV['new_string']

      aspace_client = FolioSync::ArchivesSpace::Client.new(instance_key)
      aspace_client.update_string_1_field(repo_id, resource_id, new_string)
    end
  end
end
