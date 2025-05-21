# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  default from: Rails.configuration.folio_sync['default_sender_email_address']
  layout 'mailer'

  DISPLAY_LIMIT = 50

  def folio_sync_error_email
    downloading_errors = params[:downloading_errors] || []
    syncing_errors = params[:syncing_errors] || []

    body_content = format_folio_sync_errors(
      downloading_errors: downloading_errors,
      syncing_errors: syncing_errors
    )

    mail(
      to: params[:to],
      subject: params[:subject],
      body: body_content,
      content_type: 'text/plain'
    )
  end

  private

  def format_folio_sync_errors(downloading_errors:, syncing_errors:, display_limit: DISPLAY_LIMIT)
    body_content = "One or more errors were encountered during FOLIO sync:\n\n"
    body_content += "Total Errors: #{downloading_errors.size + syncing_errors.size}\n"
    body_content += "Downloading Errors: #{downloading_errors.size}\n"
    body_content += "Syncing Errors: #{syncing_errors.size}\n\n"

    body_content += format_error_section(downloading_errors, 'Downloading Errors', display_limit)
    body_content += format_error_section(syncing_errors, 'Syncing Errors', display_limit)

    body_content
  end

  def format_error_section(errors, title, display_limit)
    return '' if errors.blank?

    content = "======== #{title} ========\n"
    errors.first(display_limit).each do |error|
      content += "Resource URI: #{error.resource_uri}\n" if error.respond_to?(:resource_uri)
      content += "Bib ID: #{error.bib_id}\n" if error.respond_to?(:bib_id)
      content += "Error: #{error.message}\n"
      content += "--------\n\n"
    end
    content += "+#{errors.size - display_limit} additional error(s)\n\n" if errors.size > display_limit
    content
  end
end
