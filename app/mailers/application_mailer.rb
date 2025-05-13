class ApplicationMailer < ActionMailer::Base
  default from: Rails.configuration.folio_sync['default_sender_email_address']
  layout 'mailer'

  def folio_sync_error_email
    body_content = "One or more errors were encountered during FOLIO sync:\n\n"

    if params[:downloading_errors].present?
      body_content += "Downloading Errors:\n"
      body_content += params[:downloading_errors].join("\n")
      body_content += "\n\n"
    end

    if params[:syncing_errors].present?
      body_content += "Syncing Errors:\n"
      body_content += params[:syncing_errors].join("\n")
      body_content += "\n"
    end

    mail(
      to: params[:to],
      subject: params[:subject],
      body: body_content,
      content_type: 'text/plain'
    )
  end
end

