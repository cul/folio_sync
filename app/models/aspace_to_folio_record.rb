# frozen_string_literal: true

class AspaceToFolioRecord < ApplicationRecord
  enum :pending_update, { no_update: 0, to_folio: 1, to_aspace: 2 }

  validates :archivesspace_instance_key, presence: true
  validates :repository_key, presence: true
  validates :resource_key, presence: true

  def self.create_or_update_from_data(data)
    if data[:folio_hrid].present?
      puts 'FOLIO HRID is present'
      existing_record = find_by(folio_hrid: data[:folio_hrid])

      if existing_record
        puts "Found existing record with folio_hrid: #{data[:folio_hrid]}"
        # Update the existing record with pending_update, is_folio_suppressed and folio_hrid
        # Other fields remain unchanged
        update_attributes = {}
        update_attributes[:pending_update] = data[:pending_update] if data.key?(:pending_update)
        update_attributes[:is_folio_suppressed] = data[:is_folio_suppressed] if data.key?(:is_folio_suppressed)
        update_attributes[:folio_hrid] = data[:folio_hrid] if data.key?(:folio_hrid)

        existing_record.update!(update_attributes)
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
