# frozen_string_literal: true

namespace :folio_sync do
  desc 'Get MARC resources'

  task run: :environment do
    puts 'Fetching MARC resources...'
    processor = FolioSync::FolioSynchronizer.new
    processor.fetch_recent_marc_resources

    puts 'Script completed successfully.'
  end

  task test: :environment do
    puts 'Testing ASPace client...'

    client = FolioSync::ArchivesSpace::Client.instance
    client.get_all_repositories.each do |repo|
      puts "Repository ID: #{repo['uri']}"
    end
  end

  task :email_test => :environment do
    ApplicationMailer.with(
      to: 'testemail@test.com',
      subject: 'Hysync Test Marc Sync Error Email',
      errors: ['Test error 1', 'Test error 2']
    ).folio_sync_error_email.deliver
  end
end
