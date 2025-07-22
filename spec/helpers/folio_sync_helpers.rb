# frozen_string_literal: true

module FolioSyncTestHelpers
  # Replicates the logic from config/initializers/folio_sync.rb
  def setup_folio_sync_directories(folio_config = nil)
    folio_config ||= Rails.configuration.folio_sync
    return if folio_config.blank?

    aspace_to_folio_config = folio_config[:aspace_to_folio]
    downloaded_files_dir = aspace_to_folio_config[:marc_download_base_directory]
    prepared_files_dir = aspace_to_folio_config[:prepared_marc_directory]

    aspace_instances = aspace_to_folio_config[:aspace_instances]

    return if aspace_instances.nil? || downloaded_files_dir.nil? || prepared_files_dir.nil?

    aspace_instances.each_key do |instance_name|
      instance_downloads_dir = File.join(downloaded_files_dir, instance_name.to_s)
      instance_prepared_dir = File.join(prepared_files_dir, instance_name.to_s)
      FileUtils.mkdir_p(instance_downloads_dir)
      FileUtils.mkdir_p(instance_prepared_dir)
    end
  end

  # Helper to clean up test directories
  def cleanup_folio_sync_directories(downloads_dir, prepared_dir)
    FileUtils.rm_rf(downloads_dir) if File.exist?(downloads_dir)
    FileUtils.rm_rf(prepared_dir) if File.exist?(prepared_dir)
  end

  # Helper to create a standard folio_sync test configuration
  def build_folio_sync_config(downloaded_files_dir:, prepared_files_dir:, aspace_instances: {})
    {
      default_sender_email_address: 'test@example.com',
      aspace_to_folio: {
        marc_download_base_directory: downloaded_files_dir,
        prepared_marc_directory: prepared_files_dir,
        aspace_instances: aspace_instances
      }
    }
  end

  RSpec.shared_context 'FolioSync directory setup' do
    include FolioSyncTestHelpers

    let(:base_dir) { 'tmp/test/downloaded_files' }
    let(:prepared_dir) { 'tmp/test/prepared_files' }
    let(:instance_key) { :test_instance }

    let(:folio_sync_config) do
      build_folio_sync_config(
        downloaded_files_dir: base_dir,
        prepared_files_dir: prepared_dir,
        aspace_instances: {
          instance_key => {
            marc_sync_email_addresses: ['test@example.com']
          }
        }
      )
    end

    before do
      allow(Rails.configuration).to receive(:folio_sync).and_return(folio_sync_config)
      setup_folio_sync_directories(folio_sync_config)
    end

    after do
      cleanup_folio_sync_directories(base_dir, prepared_dir)
    end
  end
end
