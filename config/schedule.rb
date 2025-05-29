# frozen_string_literal: true

# Use this file to easily define all of your cron jobs.
# Learn more: http://github.com/javan/whenever

require File.expand_path("#{File.dirname(__FILE__)}/environment")
# require File.expand_path('../config/environment', __dir__)

set :environment, Rails.env

# Log cron output to app log directory
set :output, Rails.root.join('log/test_cron_log.log').to_s

job_type :rake, 'cd :path && :environment_variable=:environment bundle exec rake :task :output'

# puts "Running in #{Rails.env} environment"
if Rails.env.development?
  puts 'Confirming: Running in development environment'
  every 1.minute do
    rake 'folio_sync:aspace_to_folio:email_test instance_key=cul'
  end
end

# if Rails.env.folio_sync_prod?
#   every 1.day, at: '8:00 pm' do
#     rake 'folio_sync:aspace_to_folio:run instance_key=cul modified_since=25'
#     rake 'folio_sync:aspace_to_folio:run instance_key=barnard modified_since=25'
#   end
# end
