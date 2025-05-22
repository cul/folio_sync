# frozen_string_literal: true

# Ensure that MARC download directory exists
folio_config = Rails.configuration.folio_sync

if folio_config.present?
  base_dir = folio_config['marc_download_base_directory']
  instances = folio_config['instances'] || {}

  instances.each_key do |instance_name|
    instance_dir = File.join(base_dir, instance_name.to_s)
    FileUtils.mkdir_p(instance_dir)
  end
end
