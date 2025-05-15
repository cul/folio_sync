# frozen_string_literal: true

# Ensure that MARC download directory exists
FileUtils.mkdir_p(Rails.configuration.folio_sync['marc_download_directory'])
