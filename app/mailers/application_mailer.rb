class ApplicationMailer < ActionMailer::Base
  default from: Rails.configuration.folio_sync['default_sender_email_address']
  layout 'mailer'

  def folio_sync_error_email
    body_content = "One or more errors were encountered during FOLIO sync:\n\n"

    # Downloading errors contain resource_uri and error message
    if params[:downloading_errors].present?
      body_content += "======== Downloading Errors ======== \n"
      params[:downloading_errors].each do |error|
        body_content += "Resource URI: #{error[:resource_uri]}\n"
        body_content += "Error: #{error[:error]}\n"
        body_content += "--------\n\n"
      end
    end

    # Syncing errors contain bib_id and error message
    if params[:syncing_errors].present?
      body_content += "======== Syncing Errors ======== \n"
      params[:syncing_errors].each do |error|
        body_content += "Bib ID: #{error[:bib_id]}\n"
        body_content += "Error: #{error[:error]}\n"
        body_content += "--------\n\n"
      end
    end

    mail(
      to: params[:to],
      subject: params[:subject],
      body: body_content,
      content_type: 'text/plain'
    )
  end
end

