# frozen_string_literal: true

class FolioSync::Rake::ErrorLogger
  def self.log_errors_to_console(processor)
    error_types = [
      { errors: processor.fetching_errors, label: 'Fetching errors' },
      { errors: processor.saving_errors, label: 'Saving errors' },
      { errors: processor.downloading_errors, label: 'Downloading errors' },
      { errors: processor.syncing_errors, label: 'Syncing errors' }
    ]

    error_types.each do |error_type|
      next if error_type[:errors].empty?

      Rails.logger.debug("#{error_type[:label]}:")
      error_type[:errors].each do |error|
        Rails.logger.debug "Resource URI: #{error.resource_uri}" if error.resource_uri
        Rails.logger.debug "Error: #{error.message}"
        Rails.logger.debug '----------'
      end
      Rails.logger.debug '=========================='
    end
  end

  def self.any_errors?(processor)
    processor.fetching_errors.any? ||
      processor.saving_errors.any? ||
      processor.downloading_errors.any? ||
      processor.syncing_errors.any?
  end
end
