# frozen_string_literal: true

source 'https://rubygems.org'

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem 'rails', '~> 8.0.2'
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem 'propshaft'
# Use the Puma web server [https://github.com/puma/puma]
gem 'puma', '>= 5.0'

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: %i[windows jruby]

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem 'kamal', require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem 'thruster', require: false

# Version 1.18 doesn't run on a Linux because our GLIBC version is less than required 2.29
# Nokogiri 1.17 runs successfully
gem 'nokogiri', '~> 1.17.2'

# For cron tasks
gem 'whenever', require: false

# Only used in prod environments
gem 'mysql2'

gem 'activerecord', '~> 8.0.2'

gem 'archivesspace-client'

gem 'actionmailer', '~> 8.0.2'

gem 'marc'

gem 'folio_api_client', '~> 0.4.0'

group :development, :test do
  # Use SQLite as the database for Active Record, MySQL will be used in production
  gem 'sqlite3'

  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem 'debug', platforms: %i[mri windows], require: 'debug/prelude'

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem 'brakeman', require: false

  gem 'rspec-rails', '~> 8.0.0'

  gem 'pry', '~> 0.15.0'

  # rubocop + CUL presets
  gem 'rubocul', '~> 4.0.3'

  gem 'simplecov', require: false

  gem 'factory_bot_rails'
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem 'web-console'

  gem 'capistrano', '~> 3.19.2', require: false
  gem 'capistrano-cul', require: false # common set of tasks shared across cul apps
  gem 'capistrano-passenger', '~> 0.1', require: false # allows restart passenger workers
  gem 'capistrano-rails', '~> 1.4', require: false
end
