# frozen_string_literal: true

namespace :aspace_analysis do
  task create_csv: :environment do
    FolioSync::Rake::EnvValidator.validate!(
      ['instance_key'],
      'bundle exec rake aspace_analysis:create_csv instance_key=cul'
    )
    instance_key = ENV['instance_key']

    updater = FolioSync::ArchivesSpace::ManualUpdater.new(instance_key)
    updater.retrieve_sync_aspace_resources
  end
end
