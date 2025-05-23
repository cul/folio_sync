# frozen_string_literal: true

module FolioSyncTestHelpers
  # Replicates the logic from config/initializers/folio_sync.rb
  def setup_folio_sync_directories(folio_config = nil)
    folio_config ||= Rails.configuration.folio_sync
    return if folio_config.blank?

    base_dir = folio_config['marc_download_base_directory']
    instances = folio_config['instances'] || {}

    instances.each_key do |instance_name|
      instance_dir = File.join(base_dir, instance_name.to_s)
      FileUtils.mkdir_p(instance_dir)
    end
  end

  # Helper to clean up test directories
  def cleanup_folio_sync_directories(base_dir)
    FileUtils.rm_rf(base_dir) if File.exist?(base_dir)
  end

  # Helper to create a standard folio_sync test configuration
  def build_folio_sync_config(base_dir:, instances: {})
    {
      'marc_download_base_directory' => base_dir,
      'default_sender_email_address' => 'test@example.com',
      'instances' => instances
    }
  end
end

RSpec.shared_context 'FolioSync directory setup' do
  include FolioSyncTestHelpers

  let(:base_dir) { 'tmp/test/downloaded_files' }
  let(:instance_key) { 'test_instance' }

  let(:folio_sync_config) do
    build_folio_sync_config(
      base_dir: base_dir,
      instances: {
        instance_key => {
          'marc_sync_email_addresses' => ['test@example.com']
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
