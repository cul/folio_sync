# frozen_string_literal: true

require Rails.root.join('config/environments/deployed.rb')

Rails.application.configure do
  config.log_level = :info
  config.action_mailer.default_url_options = { host: 'diglib-rails-test1.cul.columbia.edu' }
end
