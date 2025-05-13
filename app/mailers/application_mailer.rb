class ApplicationMailer < ActionMailer::Base
  default from: Rails.configuration.folio_sync['default_sender_email_address']
  layout 'mailer'

  def folio_sync_error_email
    mail(
      to: params[:to],
      subject: params[:subject],
      body: "One or more errors were encountered during FOLIO sync:\n\n" + params[:errors].join("\n") + "\n",
    	content_type: 'text/plain'
    )
  end
end

