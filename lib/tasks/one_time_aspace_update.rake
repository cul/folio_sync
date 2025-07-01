# frozen_string_literal: true

namespace :one_time_aspace_update do
  # This task should be run once before ArchivesSpace resources are ready to be synced to FOLIO.
  task update_boolean_1_fields: :environment do
    FolioSync::Rake::EnvValidator.validate!(
      ['instance_key'],
      'bundle exec rake one_time_aspace_update:update_boolean_1_fields instance_key=cul'
    )
    instance_key = ENV['instance_key']

    updater = FolioSync::ArchivesSpace::ManualUpdater.new(instance_key)
    updater.retrieve_and_sync_aspace_resources
  end
end
