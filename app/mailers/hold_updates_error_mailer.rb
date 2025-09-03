# frozen_string_literal: true

# TODO: Move the existing ApplicationMailer into something more specific
# and keep ApplicationMailer as the base class for all mailers.
class FolioHoldUpdatesErrorMailer < ApplicationMailer
  default from: Rails.configuration.folio_sync['default_sender_email_address']
  layout 'mailer'

  def hold_update_error_email
    body_content = format_errors(errors)

    mail(
      to: params[:to],
      subject: params[:subject],
      body: body_content,
      content_type: 'text/plain'
    )
  end

  def format_errors(errors)
    content = "The following errors were encountered while updating holds in FOLIO:\n\n"
    errors.each_with_index do |error, index|
      content += "#{index + 1}. #{error}\n"
    end
    content
  end
end
