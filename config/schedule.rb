# frozen_string_literal: true

# Use this file to easily define all of your cron jobs.
# Learn more: http://github.com/javan/whenever

require File.expand_path('../config/environment', __dir__)

set :environment, Rails.env

# Log cron output to app log directory
set :output, Rails.root.join("log/#{Rails.env}_cron_log.log")

set :email_subject, 'FOLIO Sync Cron Error (via Whenever Gem)'
set :error_recipient, Rails.configuration.folio_sync[:aspace_to_folio][:developer_email_address]
set :job_template, "/usr/local/bin/mailifrc -s 'Error - :email_subject' :error_recipient -- /bin/bash -l -c ':job'"

job_type :rake, 'cd :path && :environment_variable=:environment bundle exec rake :task --silent :output'

if Rails.env.folio_sync_prod? # rubocop:disable Rails/UnknownEnv
  # Remove permanent hold on items returned from ReCAP
  every 1.day, at: '7:00 pm' do
    rake 'folio_hold_request_update:run repo_key=rbml'
  end

  # Sync ArchivesSpace resources to FOLIO
  every 1.day, at: '8:00 pm' do
    rake 'folio_sync:aspace_to_folio:run instance_key=cul clear_downloads=false modified_since=25'
    # rake 'folio_sync:aspace_to_folio:run instance_key=barnard modified_since=25'
  end
end
