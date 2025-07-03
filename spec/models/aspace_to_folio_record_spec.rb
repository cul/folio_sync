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

  describe '.create_or_update_from_data' do
    let(:base_data) do
      {
        archivesspace_instance_key: 'test_instance',
        repository_key: 2,
        resource_key: 123
      }
    end

    context 'when creating a new record' do
      it 'creates a new record with the provided data' do
        data = base_data.merge(
          folio_hrid: 'test_hrid',
          pending_update: 'no_update',
          is_folio_suppressed: true
        )

        expect { AspaceToFolioRecord.create_or_update_from_data(data) }
          .to change(AspaceToFolioRecord, :count).by(1)

        record = AspaceToFolioRecord.find_by(base_data)
        expect(record.archivesspace_instance_key).to eq('test_instance')
        expect(record.repository_key).to eq(2)
        expect(record.resource_key).to eq(123)
        expect(record.folio_hrid).to eq('test_hrid')
        expect(record.pending_update).to eq('no_update')
        expect(record.is_folio_suppressed).to be true
      end

      it 'creates a record with only required fields when optional fields are not provided' do
        expect { AspaceToFolioRecord.create_or_update_from_data(base_data) }
          .to change(AspaceToFolioRecord, :count).by(1)

        record = AspaceToFolioRecord.find_by(base_data)
        expect(record.archivesspace_instance_key).to eq('test_instance')
        expect(record.repository_key).to eq(2)
        expect(record.resource_key).to eq(123)
        expect(record.folio_hrid).to be_nil
        expect(record.pending_update).to eq('to_folio') # default value is 'to_folio'
        expect(record.is_folio_suppressed).to be false # default value from schema
      end
    end

    context 'when updating an existing record' do
      let!(:existing_record) do
        AspaceToFolioRecord.create!(
          archivesspace_instance_key: 'test_instance',
          repository_key: 2,
          resource_key: 123,
          folio_hrid: 'old_hrid',
          pending_update: 'no_update',
          is_folio_suppressed: false
        )
      end

      it 'updates the existing record with new data' do
        data = base_data.merge(
          folio_hrid: 'new_hrid',
          pending_update: 'to_aspace',
          is_folio_suppressed: true
        )

        expect { AspaceToFolioRecord.create_or_update_from_data(data) }
          .not_to change(AspaceToFolioRecord, :count)

        existing_record.reload
        expect(existing_record.folio_hrid).to eq('new_hrid')
        expect(existing_record.pending_update).to eq('to_aspace')
        expect(existing_record.is_folio_suppressed).to be true
      end

      it 'does not update fields that are not present in the data hash' do
        expect { AspaceToFolioRecord.create_or_update_from_data(base_data) }
          .not_to change(AspaceToFolioRecord, :count)

        existing_record.reload
        expect(existing_record.folio_hrid).to eq('old_hrid')
        expect(existing_record.pending_update).to eq('no_update')
        expect(existing_record.is_folio_suppressed).to be false
      end
    end

    context 'validation errors' do
      it 'raises an error if validation fails' do
        invalid_data = { repository_key: 99, resource_key: 999 } # missing required archivesspace_instance_key

        expect { AspaceToFolioRecord.create_or_update_from_data(invalid_data) }
          .to raise_error(ActiveRecord::RecordInvalid)
      end
    end
  end

  describe '#archivesspace_marc_xml_path' do
    let(:record) do
      AspaceToFolioRecord.new(
        archivesspace_instance_key: 'test_instance',
        repository_key: 5,
        resource_key: 42
      )
    end

    it 'returns the correct path format' do
      expected_path = 'test_instance/5-42-aspace.xml'
      expect(record.archivesspace_marc_xml_path).to eq(expected_path)
    end
  end

  describe '#folio_marc_xml_path' do
    let(:record) do
      AspaceToFolioRecord.new(
        archivesspace_instance_key: 'test_instance',
        repository_key: 5,
        resource_key: 42
      )
    end

    it 'returns the correct path format' do
      expected_path = 'test_instance/5-42-folio.xml'
      expect(record.folio_marc_xml_path).to eq(expected_path)
    end
  end
end