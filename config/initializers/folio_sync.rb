# frozen_string_literal: true

# Ensure that MARC download directories exist
begin
  logger = Logger.new($stdout)
  folio_config = Rails.configuration.folio_sync
  aspace_to_folio_config = folio_config[:aspace_to_folio]

  if folio_config.blank?
    logger.error('FOLIO sync configuration is missing or empty')
    throw 'Please make sure the folio_sync.yml file is present and properly configured.'
  end

  aspace_instances = aspace_to_folio_config[:aspace_instances] || {}

  if aspace_instances.empty?
    logger.error('No aspace_instances configured')
    throw 'Please make sure the folio_sync.yml file contains aspace_instances'
  end

  developer_email_address = aspace_to_folio_config[:developer_email_address]

  if developer_email_address.blank?
    logger.error('Developer email address is not configured')
    throw 'Please make sure the folio_sync.yml file contains a developer_email_address'
  end

  base_dir = aspace_to_folio_config[:marc_download_base_directory]

  # If the base directory is not present, set a default base directory
  if base_dir.blank?
    current_env = Rails.env
    base_dir = Rails.root.join("tmp/#{current_env}/downloaded_files")
    logger.warn("MARC download directory is not configured, defaulting to #{base_dir}")
    aspace_to_folio_config[:marc_download_base_directory] = base_dir
  end

  aspace_instances.each_key do |instance_name|
    instance_dir = File.join(base_dir, instance_name.to_s)
    FileUtils.mkdir_p(instance_dir)
  end
rescue StandardError => e
  logger.error("Failed to initialize FOLIO Sync directories: #{e.message}")
  exit(1)
end
