# This task retrieves all open, not yet filled requests for a specific requester barcode
# and attempts to check out each item associated with those requests.
# Checking out an item allows the hold to be changed from a permanent hold to a temporary hold
# which clears after 24 hours.
namespace :folio_hold_request_update do
  desc 'Process open, not yet filled requests and check out items'
  task run: :environment do
    updater = FolioSync::Folio::ItemHoldUpdater.new
    updater.remove_permanent_holds_from_items

    if updater.updater_errors.any?
      puts 'Errors encountered during hold removal:'
      updater.updater_errors.each do |error|
        puts error
      end

      FolioHoldUpdatesErrorMailer.with(
          to: Rails.configuration.folio_sync[:aspace_to_folio][:developer_email_address],
          subject: 'Errors updating holds in FOLIO',
          errors: updater.updater_errors
        ).hold_update_error_email.deliver
    else
      puts 'All holds have been removed successfully.'
    end
  end
end

