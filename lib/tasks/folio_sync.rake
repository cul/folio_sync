# frozen_string_literal: true

namespace :folio_sync do
  desc 'Get MARC resources'

  task run: :environment do
    puts 'Fetching MARC resources...'
    processor = FolioSync::FolioSynchronizer.new
    processor.fetch_and_sync_resources_to_folio

    puts 'Script completed successfully.'
  end

  task test: :environment do
    puts 'Testing FOLIO client...'

    marc = FolioSync::Folio::TestRecord.new('bibid-test')
    marc.process_record
  end
end
