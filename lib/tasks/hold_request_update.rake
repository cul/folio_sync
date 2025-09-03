# frozen_string_literal: true

# This task retrieves all open, not yet filled requests for a specific requester barcode
# and attempts to check out each item associated with those requests.
# Checking out an item allows the hold to be changed from a permanent hold to a temporary hold
# which clears after 24 hours.
namespace :folio_hold_request_update do
  desc 'Process open, not yet filled requests and check out items'
  task run: :environment do
    FolioSync::Rake::EnvValidator.validate!(
      ['repo_key'],
      'bundle exec rake folio_hold_request_update:run repo_key=rbml'
    )
    repo_key = ENV['repo_key']

    test_errors = ['Test error', 'Another test error']

    FolioHoldUpdatesErrorMailer.with(
        to: Rails.configuration.folio_requests[:repos][repo_key.to_sym][:cron_email_addresses],
        subject: 'Test error!',
        errors: test_errors
      ).hold_update_error_email.deliver

    # updater = FolioSync::Folio::ItemHoldUpdater.new(repo_key)
    # updater.remove_permanent_holds_from_items

    # if updater.updater_errors.any?
    #   puts 'Errors encountered during hold removal:'
    #   updater.updater_errors.each do |error|
    #     puts error
    #   end

    #   FolioHoldUpdatesErrorMailer.with(
    #     to: Rails.configuration.folio_requests[:repos][repo_key.to_sym][:cron_email_addresses],
    #     subject: 'Errors updating holds in FOLIO',
    #     errors: updater.updater_errors
    #   ).hold_update_error_email.deliver
    # else
    #   puts 'All holds have been removed successfully.'
    # end
  end
end
