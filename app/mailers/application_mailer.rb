# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  default from: Rails.configuration.folio_sync['default_sender_email_address']
  layout 'mailer'
end
