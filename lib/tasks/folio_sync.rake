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
      mode = ENV.fetch('mode', 'all').to_sym

      # Optional environment variables
      modified_since = ENV['modified_since']
      clear_downloads = (mode != :sync)
      puts "Will downloads be cleared? #{clear_downloads}"

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
      processor.fetch_and_sync_aspace_to_folio_records(modified_since_time, mode)

      if FolioSync::Rake::ErrorLogger.any_errors?(processor)
        FolioSync::Rake::ErrorLogger.log_errors_to_console(processor)

        ApplicationMailer.with(
          to: recipients_for(instance_key),
          subject: 'FOLIO Sync Errors',
          fetching_errors: processor.fetching_errors,
          saving_errors: processor.saving_errors,
          downloading_errors: processor.downloading_errors,
          syncing_errors: processor.syncing_errors,
          linking_errors: processor.linking_errors
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
    # bundle exec rake folio_sync:aspace_to_folio:process_marc_without_folio instance_key=<instance_key> file_name=<file_name>'
    desc 'Create an enhanced MARC record from a MARC XML file'
    task process_marc_without_folio: :environment do
      FolioSync::Rake::EnvValidator.validate!(
        ['instance_key', 'file_name'],
        'bundle exec rake folio_sync:aspace_to_folio:process_marc_without_folio instance_key=instance_name file_name=test.xml'
      )

      instance_key = ENV['instance_key']
      file_path = construct_file_path(instance_key, ENV['file_name'])

      enhanced_marc_record = FolioSync::ArchivesSpaceToFolio::MarcRecordEnhancer.new(
        file_path,
        nil, # We don't need to pass a FOLIO MARC record for this example
        nil, # HRID is used only to manipulate controlfield 001
        instance_key
      ).enhance_marc_record!

      puts "Processed MARC record: #{enhanced_marc_record}"
    end

    # Add two MARC XML test files to the directory specified in folio_sync.yml
    # Run as:
    # bundle exec rake folio_sync:aspace_to_folio:process_marc_with_folio instance_key=<instance_key>
    # aspace_file=<file_name> folio_file=<file_name>
    task process_marc_with_folio: :environment do
      FolioSync::Rake::EnvValidator.validate!(
        ['instance_key', 'aspace_file', 'folio_file'],
        'bundle exec rake folio_sync:aspace_to_folio:process_marc_with_folio ' \
        'instance_key=cul aspace_file_name=aspace_record.xml ' \
        'folio_file_name=folio_record.xml'
      )

      instance_key = ENV['instance_key']
      aspace_file_path = construct_file_path(instance_key, ENV['aspace_file'])
      folio_file_path = construct_file_path(instance_key, ENV['folio_file'])

      enhanced_marc_record = FolioSync::ArchivesSpaceToFolio::MarcRecordEnhancer.new(
        aspace_file_path,
        folio_file_path,
        'This HRID should be visible in the controlfield 001',
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
        ],
        linking_errors: [
          FolioSync::Errors::LinkingError.new(resource_uri: '/uri-test-6', message: 'Error test 6')
        ]
      ).folio_sync_error_email.deliver
    end

    def construct_file_path(instance_key, file_name)
      base_dir = Rails.configuration.folio_sync[:aspace_to_folio][:marc_download_base_directory]
      File.join(base_dir, instance_key, file_name)
    end
  end
end
