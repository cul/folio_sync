namespace :script do
  desc "Get MARC resources"

  task :run => :environment do
    # puts Rails.configuration.archivesspace["ASPACE_BASE_API"]
    require "folio_processor/folio_synchronizer"

    puts "Fetching MARC resources..."
    processor = FOLIOSynchronizer.new
    processor.fetch_recent_marc_resources

    puts "Script completed successfully."
  end
end