namespace :folio_sync do
  desc "Get MARC resources"

  task :run => :environment do
    require "folio_sync/folio_synchronizer"

    puts "Fetching MARC resources..."
    processor = FolioSync::FolioSynchronizer.new
    processor.fetch_recent_marc_resources

    puts "Script completed successfully."
  end
end