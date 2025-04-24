namespace :folio_sync do
  desc "Get MARC resources"

  task :run => :environment do
    require "folio_sync/folio_synchronizer"

    puts "Fetching MARC resources..."
    processor = FolioSync::FolioSynchronizer.new
    processor.fetch_recent_marc_resources

    puts "Script completed successfully."
  end

  task :test => :environment do
    require "folio_sync/archives_space/client"

    puts "Testing ASPace client..."
    client = FolioSync::ArchivesSpace::Client.instance
    client.get_all_repositories.each do |repo|
      puts "Repository ID: #{repo['uri']}"
    end

  end
end