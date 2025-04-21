namespace :script do
  desc "Get MARC resources"

  task :run => :environment do
    # puts Rails.configuration.archivesspace["ASPACE_BASE_API"]
    require "aspace_processor/refactored_search_repo_class"

    puts "Fetching MARC resources..."
    processor = RefactoredSearchRepoClass.new
    processor.fetch_recent_marc_resources

    puts "Script completed successfully."
  end
end