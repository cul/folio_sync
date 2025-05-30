# frozen_string_literal: true

module FolioSyncTestHelpers
  # Replicates the logic from config/initializers/folio_sync.rb
  def setup_folio_sync_directories(folio_config = nil)
    folio_config ||= Rails.configuration.folio_sync
    return if folio_config.blank?

    aspace_to_folio_config = folio_config[:aspace_to_folio]
    base_dir = aspace_to_folio_config[:marc_download_base_directory]
    aspace_instances = aspace_to_folio_config[:aspace_instances]

    return if aspace_instances.nil? || base_dir.nil?

    aspace_instances.each_key do |instance_name|
      instance_dir = File.join(base_dir, instance_name.to_s)
      daily_sync_dir = File.join(instance_dir, 'daily_sync')
      manual_sync_dir = File.join(instance_dir, 'manual_sync')

      # Create the directories
      FileUtils.mkdir_p(daily_sync_dir)
      FileUtils.mkdir_p(manual_sync_dir)
    end
  end

  # Helper to clean up test directories
  def cleanup_folio_sync_directories(base_dir)
    FileUtils.rm_rf(base_dir) if File.exist?(base_dir)
  end

  # Helper to create a standard folio_sync test configuration
  def build_folio_sync_config(base_dir:, aspace_instances: {})
    {
      default_sender_email_address: 'test@example.com',
      aspace_to_folio: {
        marc_download_base_directory: base_dir,
        aspace_instances: aspace_instances
      }
    }
  end

  RSpec.shared_context 'FolioSync directory setup' do
    include FolioSyncTestHelpers

    let(:base_dir) { 'tmp/test/downloaded_files' }
    let(:instance_key) { :test_instance }

    let(:folio_sync_config) do
      build_folio_sync_config(
        base_dir: base_dir,
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
      cleanup_folio_sync_directories(base_dir)
    end
  end
end
