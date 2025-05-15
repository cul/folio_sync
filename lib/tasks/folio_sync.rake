# frozen_string_literal: true

namespace :folio_sync do
  namespace :aspace_to_folio do
    desc 'Fetch ArchivesSpace MARC resources and sync to FOLIO'
    task run: :environment do
      puts 'Fetching MARC resources...'
      processor = FolioSync::ArchivesSpaceToFolio::FolioSynchronizer.new
      processor.fetch_and_sync_resources_to_folio

      # Send email if there are any errors
      if processor.syncing_errors.any? || processor.downloading_errors.any?
        puts 'Errors occurred during processing:'

        unless processor.downloading_errors.empty?
          puts 'Downloading errors:'
          puts processor.downloading_errors
          puts "=========================="
        end

        unless processor.syncing_errors.empty?
          puts 'Syncing errors:'
          puts processor.syncing_errors
          puts "=========================="
        end

        ApplicationMailer.with(
          to: Rails.configuration.folio_sync['marc_sync_email_addresses'],
          subject: 'FOLIO Sync Errors',
          downloading_errors: processor.downloading_errors,
          syncing_errors: processor.syncing_errors,
        ).folio_sync_error_email.deliver
      else
        puts 'Script completed successfully.'
      end
    end

    desc 'Sync already downloaded resources to FOLIO'
    task :sync_exported_resources => :environment do
      puts 'Syncing exported resources...'
      processor = FolioSync::ArchivesSpaceToFolio::FolioSynchronizer.new
      processor.sync_resources_to_folio

      if processor.syncing_errors.any?
        puts 'Errors occurred during syncing:'
        puts processor.syncing_errors
        ApplicationMailer.with(
          to: Rails.configuration.folio_sync['marc_sync_email_addresses'],
          subject: 'FOLIO Sync - Error syncing exported resources',
          syncing_errors: processor.syncing_errors
        ).folio_sync_error_email.deliver
      else
        puts 'Syncing completed successfully.'
      end
    end

    # Add a MARC XML test file to tmp/marc_files directory to verify the processing
    # Run as:
    # rake 'folio_sync:aspace_to_folio:process_marc_xml[<bib_id>]'
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
    task :email_test => :environment do
      ApplicationMailer.with(
        to: Rails.configuration.folio_sync['marc_sync_email_addresses'],
        subject: 'FOLIO Test - Marc Sync Errors',
        errors: ['Test error 1', 'Test error 2']
      ).folio_sync_error_email.deliver
    end
  end
end
