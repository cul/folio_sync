namespace :folio_sync do
  desc "Get MARC resources"

  task :run => :environment do
    puts "Fetching MARC resources..."
    processor = FolioSync::FolioSynchronizer.new
    processor.fetch_recent_marc_resources

    puts "Script completed successfully."
  end

  task :test => :environment do
    puts "Testing ASPace client..."

    client = FolioSync::ArchivesSpace::Client.instance
    client.get_all_repositories.each do |repo|
      puts "Repository ID: #{repo['uri']}"
    end
  end
end