require 'rails_helper'

RSpec.describe AspaceToFolioRecord, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      record = AspaceToFolioRecord.new(
        archivesspace_instance_key: 'instance_key',
        repository_key: 1,
        resource_key: 1,
        folio_hrid: 'folio_hrid',
        is_folio_suppressed: false
      )
      expect(record).to be_valid
    end

    it 'is invalid without archivesspace_instance_key' do
      record = AspaceToFolioRecord.new(
        repository_key: 1,
        resource_key: 1,
        folio_hrid: 'folio_hrid',
        is_folio_suppressed: false
      )
      expect(record).not_to be_valid
      expect(record.errors[:archivesspace_instance_key]).to include("can't be blank")
    end

    it 'is invalid without repository_key' do
      record = AspaceToFolioRecord.new(
        archivesspace_instance_key: 'instance_key',
        resource_key: 1,
        folio_hrid: 'folio_hrid',
        is_folio_suppressed: false
      )
      expect(record).not_to be_valid
      expect(record.errors[:repository_key]).to include("can't be blank")
    end

    it 'is invalid without resource_key' do
      record = AspaceToFolioRecord.new(
        archivesspace_instance_key: 'instance_key',
        repository_key: 1,
        folio_hrid: 'folio_hrid',
        is_folio_suppressed: false
      )
      expect(record).not_to be_valid
      expect(record.errors[:resource_key]).to include("can't be blank")
    end
  end

  describe 'enums' do
    it 'defines the correct values for pending_update' do
      expect(AspaceToFolioRecord.pending_updates.keys).to match_array(%w[no_update to_folio to_aspace])
    end
  end
end
