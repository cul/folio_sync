# frozen_string_literal: true

# Ensure that MARC download directories exist
begin
  logger = Logger.new($stdout)
  folio_config = Rails.configuration.folio_sync
  folio_to_hyacinth_config = Rails.configuration.folio_to_hyacinth
  aspace_to_folio_config = folio_config[:aspace_to_folio]

  if folio_config.blank?
    logger.error('FOLIO sync configuration is missing or empty')
    throw 'Please make sure the folio_sync.yml file is present and properly configured.'
  end

  if folio_to_hyacinth_config.blank?
    logger.error('FOLIO to Hyacinth configuration is missing or empty')
    throw 'Please make sure the folio_to_hyacinth.yml file is present and properly configured.'
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

  downloaded_files_dir = aspace_to_folio_config[:marc_download_base_directory]
  prepared_files_dir = aspace_to_folio_config[:prepared_marc_directory]

  if downloaded_files_dir.blank?
    logger.error('Directory for downloaded MARC files is not configured')
    throw 'Please make sure the folio_sync.yml file contains a marc_download_base_directory'
  end

  if prepared_files_dir.blank?
    logger.error('Directory for prepared MARC files is not configured')
    throw 'Please make sure the folio_sync.yml file contains a prepared_marc_directory'
  end

  # Prepare downloads directory for FOLIO to Hyacinth sync
  FileUtils.mkdir_p(folio_to_hyacinth_config[:download_directory])

  # Prepare subdirectories for ArchivesSpace to FOLIO sync
  aspace_instances.each_key do |instance_name|
    downloads_instance_dir = File.join(downloaded_files_dir, instance_name.to_s)
    prepared_instance_dir = File.join(prepared_files_dir, instance_name.to_s)
    FileUtils.mkdir_p(downloads_instance_dir)
    FileUtils.mkdir_p(prepared_instance_dir)
  end
rescue StandardError => e
  logger.error("Failed to initialize FOLIO Sync directories: #{e.message}")
  exit(1)
end
