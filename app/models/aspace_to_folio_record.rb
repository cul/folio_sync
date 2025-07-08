# frozen_string_literal: true

class AspaceToFolioRecord < ApplicationRecord
  enum :pending_update, { no_update: 0, to_folio: 1, to_aspace: 2 }

  validates :archivesspace_instance_key, presence: true
  validates :repository_key, presence: true
  validates :resource_key, presence: true

  def self.create_or_update_from_data(data)
    if data[:folio_hrid].present?
      existing_record = find_by(folio_hrid: data[:folio_hrid])

      if existing_record
        # Update the existing record with only pending_update and is_folio_suppressed
        # Other fields remain unchanged
        existing_record.update!(
          pending_update: data[:pending_update],
          is_folio_suppressed: data[:is_folio_suppressed]
        )
        return existing_record
      end
    end

    # Create a new record with all the data (either folio_hrid is nil or there is no existing record)
    create!(data)
  end

  def archivesspace_marc_xml_path
    "#{self.archivesspace_instance_key}/#{self.repository_key}-#{resource_key}-aspace.xml"
  end

  def folio_marc_xml_path
    "#{self.archivesspace_instance_key}/#{self.repository_key}-#{resource_key}-folio.xml"
  end
end
