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

      # Send email if there are any errors
      if processor.syncing_errors.any? || processor.downloading_errors.any?
        puts 'Errors occurred during processing:'

        unless processor.downloading_errors.empty?
          puts 'Downloading errors:'
          processor.downloading_errors.each do |error|
            puts "Resource URI: #{error.resource_uri}"
            puts "Error: #{error.message}"
          end
          puts '=========================='
        end

        unless processor.syncing_errors.empty?
          puts 'Syncing errors:'
          processor.syncing_errors.each do |error|
            puts "Bib ID: #{error.bib_id}"
            puts "Error: #{error.message}"
          end
          puts '=========================='
        end

        ApplicationMailer.with(
          to: recipients_for(instance_key),
          subject: 'FOLIO Sync Errors',
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
    # bundle exec rake folio_sync:aspace_to_folio:process_marc_xml bib_id=<bib_id>'
    # ! Quotes are necessary to pass the argument correctly
    desc 'Process a MARC XML file for a given bib_id'
    task process_marc_xml: :environment do
      FolioSync::Rake::EnvValidator.validate!(
        ['bib_id'],
        'bundle exec rake folio_sync:aspace_to_folio:process_marc_xml bib_id=123456789'
      )

      bib_id = ENV['bib_id']
      puts "Testing MARC processing for bib_id: #{bib_id}"

      enhancer = FolioSync::ArchivesSpaceToFolio::MarcRecordEnhancer.new(bib_id)
      marc_record = enhancer.enhance_marc_record!

      puts "Processed MARC record: #{marc_record}"
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
        subject: 'FOLIO Sync Errors',
        downloading_errors: [
          FolioSync::Errors::DownloadingError.new(resource_uri: '/uri-test', message: 'Error test 1')
        ],
        syncing_errors: [
          FolioSync::Errors::SyncingError.new(bib_id: '1234567', message: 'Error test 2')
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
