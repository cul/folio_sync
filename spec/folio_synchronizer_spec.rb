require 'rails_helper'

RSpec.describe FolioSync::FolioSynchronizer do
  let(:instance) { described_class.new }

  describe "#initialize" do
    it 'can be instantiated' do
      expect(instance).to be_a(described_class)
    end

    it 'initializes with the ArchivesSpace client' do
      synchronizer = described_class.new
      expect(synchronizer.instance_variable_get(:@aspace_client)).to be_a(FolioSync::ArchivesSpace::Client)
    end
  end
end
