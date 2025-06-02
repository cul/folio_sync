# frozen_string_literal: true

namespace :folio_sync do
  namespace :aspace_to_folio do
    def recipients_for(instance_key)
      Rails.configuration.folio_sync[:aspace_to_folio][:aspace_instances][instance_key.to_sym][:marc_sync_email_addresses]
    end

    desc 'Fetch ArchivesSpace MARC resources and sync to FOLIO'
    task run: :environment do
      instance_key = ENV['instance_key']
      modified_since = ENV['modified_since']
      clear_downloads = ENV['clear_downloads'].nil? || ENV['clear_downloads'] == 'true'

      unless instance_key
        puts 'Error: Please provide an instance_key.'
        puts 'Usage: bundle exec rake folio_sync:aspace_to_folio:run instance_key=cul'
        exit 1
      end

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
      processor.fetch_and_sync_resources_to_folio(modified_since_time)

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
      instance_key = ENV['instance_key']

      unless instance_key
        puts 'Error: Please provide an instance_key.'
        puts 'Usage: bundle exec rake folio_sync:aspace_to_folio:sync_exported_resources instance_key=cul'
        exit 1
      end

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
      bib_id = ENV['bib_id']

      if bib_id.nil?
        puts 'Error: Please provide a bib_id.'
        puts 'Usage: bundle exec rake folio_sync:aspace_to_folio:process_marc_xml bib_id=123456789'
        exit 1
      end

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
      instance_key = ENV['instance_key']

      unless instance_key
        puts 'Error: Please provide an instance_key.'
        puts 'Usage: bundle exec rake folio_sync:aspace_to_folio:email_test instance_key=cul'
        exit 1
      end

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
  end
end
