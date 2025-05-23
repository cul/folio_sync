# frozen_string_literal: true

# Ensure that MARC download directories exist
begin
  logger = Logger.new($stdout)
  folio_config = Rails.configuration.folio_sync

  if folio_config.blank?
    logger.error('FOLIO sync configuration is missing or empty')
    throw 'Please make sure the folio_sync.yml file is present and properly configured.'
  end

  instances = folio_config['instances'] || {}

  if instances.empty?
    logger.error('No instances configured')
    throw 'Please make sure the folio_sync.yml file contains instances'
  end

  base_dir = folio_config['marc_download_base_directory']

  # If the base directory is not present, set a default base direcotry
  if base_dir.blank?
    current_env = Rails.env
    base_dir = Rails.root.join("tmp/#{current_env}/downloaded_files")
    logger.warn("MARC download directory is not configured, defaulting to #{base_dir}")
    Rails.configuration.folio_sync['marc_download_base_directory'] = base_dir
  end

  instances.each_key do |instance_name|
    instance_dir = File.join(base_dir, instance_name.to_s)
    FileUtils.mkdir_p(instance_dir)
  end
rescue StandardError => e
  logger.error("Failed to initialize FOLIO Sync directories: #{e.message}")
  exit(1)
end
