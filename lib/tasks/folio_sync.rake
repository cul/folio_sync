# frozen_string_literal: true

namespace :folio_sync do
  namespace :aspace_to_folio do
    desc 'Fetch ArchivesSpace MARC resources and sync to FOLIO'
    task run: :environment do
      puts 'Fetching MARC resources...'
      processor = FolioSync::ArchivesSpaceToFolio::FolioSynchronizer.new
      processor.fetch_and_sync_resources_to_folio

      puts 'Script completed successfully.'
    end

    # Add a MARC XML test file to tmp/marc_files directory to verify the processing
    # Run as:
    # rake 'folio_sync:aspace_to_folio:process_marc_xml[<bib_id>]'
    # ! Quotes are necessary to pass the argument correctly
    desc 'Process a MARC XML file for a given bib_id'
    task :process_marc_xml, [:bib_id] => :environment do |_task, args|
      bib_id = args[:bib_id]

      if bib_id.nil?
        puts 'Error: Please provide a bib_id as an argument. Remember to use quotes.'
        puts "Usage: rake 'folio_sync:aspace_to_folio:process_marc_xml[<bib_id>]' "
        exit 1
      end

      puts "Testing MARC processing for bib_id: #{bib_id}"

      marc = FolioSync::ArchivesSpaceToFolio::MarcRecordEnhancer.new(bib_id)
      marc.enhance_marc_record!

      puts "Processed MARC record: #{marc.marc_record}"
    end

    desc 'Perform a health check on the FOLIO API'
    task folio_health_check: :environment do
      puts 'FOLIO health check response:'
      client = FolioSync::Folio::Client.instance
      puts client.check_health
    end
  end
end
