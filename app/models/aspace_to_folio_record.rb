# frozen_string_literal: true

class AspaceToFolioRecord < ApplicationRecord
  enum :pending_update, { no_update: 0, to_folio: 1, to_aspace: 2, fix_required: 3 }

  validates :archivesspace_instance_key, presence: true
  validates :repository_key, presence: true
  validates :resource_key, presence: true
  validates :holdings_call_number, presence: true

  def self.create_or_update_from_data(data)
    if data[:folio_hrid].present?
      existing_record = find_by(folio_hrid: data[:folio_hrid])

      if existing_record
        # Update the existing record with pending_update, is_folio_suppressed and folio_hrid
        # Other fields remain unchanged
        update_attributes = {}
        update_attributes[:pending_update] = data[:pending_update] if data.key?(:pending_update)
        update_attributes[:is_folio_suppressed] = data[:is_folio_suppressed] if data.key?(:is_folio_suppressed)
        update_attributes[:folio_hrid] = data[:folio_hrid] if data.key?(:folio_hrid)
        update_attributes[:holdings_call_number] = data[:holdings_call_number] if existing_record.holdings_call_number.blank?

        existing_record.update!(update_attributes)
        return existing_record
      end
    end

    # Create a new record with all the data (either folio_hrid is nil or there is no existing record)
    create!(data)
  end

  def archivesspace_marc_xml_path
    File.join(aspace_config[:marc_download_base_directory],
              "#{archivesspace_instance_key}/#{repository_key}-#{resource_key}-aspace.xml")
  end

  def folio_marc_xml_path
    File.join(aspace_config[:marc_download_base_directory],
              "#{archivesspace_instance_key}/#{repository_key}-#{resource_key}-folio.xml")
  end

  def prepared_folio_marc_path
    File.join(aspace_config[:prepared_marc_directory],
              "#{archivesspace_instance_key}/#{repository_key}-#{resource_key}-prepared.marc")
  end

  private

  def aspace_config
    Rails.configuration.folio_sync[:aspace_to_folio]
  end
end
