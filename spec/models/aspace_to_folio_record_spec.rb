require 'rails_helper'

RSpec.describe AspaceToFolioRecord, type: :model do
  include_context 'FolioSync directory setup'

  let(:downloads_dir) { 'tmp/test/downloaded_files' }
  let(:prepared_files_dir) { 'tmp/test/prepared_files' }
  let(:aspace_to_folio_record) { FactoryBot.create(:aspace_to_folio_record) }

  describe 'validations' do
    it 'is valid with valid attributes' do
      record = FactoryBot.build(:aspace_to_folio_record)
      expect(record).to be_valid
    end

    it 'is invalid without archivesspace_instance_key' do
      record = FactoryBot.build(:aspace_to_folio_record, archivesspace_instance_key: nil)
      expect(record).not_to be_valid
      expect(record.errors[:archivesspace_instance_key]).to include("can't be blank")
    end

    it 'is invalid without repository_key' do
      record = FactoryBot.build(:aspace_to_folio_record, repository_key: nil)
      expect(record).not_to be_valid
      expect(record.errors[:repository_key]).to include("can't be blank")
    end

    it 'is invalid without resource_key' do
      record = FactoryBot.build(:aspace_to_folio_record, resource_key: nil)
      expect(record).not_to be_valid
      expect(record.errors[:resource_key]).to include("can't be blank")
    end
  end

  describe 'enums' do
    it 'defines the correct values for pending_update' do
      expect(AspaceToFolioRecord.pending_updates.keys).to match_array(%w[no_update to_folio to_aspace fix_required])
    end
  end

  describe '.create_or_update_from_data' do
    let(:base_data) do
      {
        archivesspace_instance_key: 'test_instance',
        repository_key: 2,
        resource_key: 123,
        folio_hrid: 'test_hrid',
      }
    end

    context 'when creating a new record' do
      it 'creates a new record with the provided data' do
        data = base_data.merge(
          pending_update: 'no_update',
          is_folio_suppressed: true
        )

        expect { AspaceToFolioRecord.create_or_update_from_data(data) }
          .to change(AspaceToFolioRecord, :count).by(1)

        record = AspaceToFolioRecord.find_by(base_data)
        expect(record.archivesspace_instance_key).to eq('test_instance')
        expect(record.repository_key).to eq(2)
        expect(record.resource_key).to eq(123)
        expect(record.pending_update).to eq('no_update')
        expect(record.is_folio_suppressed).to be true
        expect(record.folio_hrid).to eq('test_hrid')
      end

      it 'creates a record with only required fields when optional fields are not provided' do
        expect { AspaceToFolioRecord.create_or_update_from_data(base_data) }
          .to change(AspaceToFolioRecord, :count).by(1)

        record = AspaceToFolioRecord.find_by(base_data)
        expect(record.archivesspace_instance_key).to eq('test_instance')
        expect(record.repository_key).to eq(2)
        expect(record.resource_key).to eq(123)
        expect(record.pending_update).to eq('to_folio') # default value is 'to_folio'
        expect(record.is_folio_suppressed).to be false # default value from schema
      end
    end

    context 'when updating an existing record' do
      let!(:existing_record) { 
        FactoryBot.create(:aspace_to_folio_record, 
                         pending_update: 'no_update', 
                         is_folio_suppressed: false, 
                         folio_hrid: 'old_hrid') 
      }

      it 'updates the existing record with new data' do
        data = {
          pending_update: 'to_aspace',
          is_folio_suppressed: true,
          folio_hrid: 'old_hrid' # Use the existing folio_hrid to find the record
        }

        expect { AspaceToFolioRecord.create_or_update_from_data(data) }
          .not_to change(AspaceToFolioRecord, :count)

        existing_record.reload
        expect(existing_record.folio_hrid).to eq('old_hrid')
        expect(existing_record.pending_update).to eq('to_aspace')
        expect(existing_record.is_folio_suppressed).to be true
      end

      it 'does not update fields that are not present in the data hash' do
        data = {
          folio_hrid: 'old_hrid' # Use the existing folio_hrid to find the record
        }

        expect { AspaceToFolioRecord.create_or_update_from_data(data) }
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
    it 'returns the correct path format' do
      instance_specific_path = "#{aspace_to_folio_record.archivesspace_instance_key}/" \
                               "#{aspace_to_folio_record.repository_key}-" \
                               "#{aspace_to_folio_record.resource_key}-aspace.xml"
      expected_path = File.join(downloads_dir, instance_specific_path)
      expect(aspace_to_folio_record.archivesspace_marc_xml_path).to eq(expected_path)
    end
  end

  describe '#folio_marc_xml_path' do
    it 'returns the correct path format' do
      instance_specific_path = "#{aspace_to_folio_record.archivesspace_instance_key}/" \
                               "#{aspace_to_folio_record.repository_key}-" \
                               "#{aspace_to_folio_record.resource_key}-folio.xml"
      expected_path = File.join(downloads_dir, instance_specific_path)
      expect(aspace_to_folio_record.folio_marc_xml_path).to eq(expected_path)
    end
  end

  describe '#prepared_folio_marc_path' do
    it 'returns the correct path format' do
      instance_specific_path = "#{aspace_to_folio_record.archivesspace_instance_key}/" \
                               "#{aspace_to_folio_record.repository_key}-" \
                               "#{aspace_to_folio_record.resource_key}-prepared.marc"
      expected_path = File.join(prepared_files_dir, instance_specific_path)
      expect(aspace_to_folio_record.prepared_folio_marc_path).to eq(expected_path)
    end
  end
end