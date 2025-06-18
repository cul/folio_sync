# frozen_string_literal: true

class AspaceToFolioRecord < ApplicationRecord
  enum :pending_update, { no_update: 0, to_folio: 1, to_aspace: 2 }

  validates :archivesspace_instance_key, presence: true
  validates :repository_key, presence: true
  validates :resource_key, presence: true

  def self.create_or_update_from_data(data)
    record = find_or_initialize_by(
      archivesspace_instance_key: data[:archivesspace_instance_key],
      repository_key: data[:repository_key],
      resource_key: data[:resource_key]
    )

    record.folio_hrid = data[:folio_hrid] if data.key?(:folio_hrid)
    record.pending_update = data[:pending_update] if data.key?(:pending_update)
    record.is_folio_suppressed = data[:is_folio_suppressed] if data.key?(:is_folio_suppressed)

    record.save!
  end

  def archivesspace_marc_xml_path
    "#{self.archivesspace_instance_key}/#{self.repository_key}-#{resource_key}-aspace.xml"
  end

  def folio_marc21_path
    "#{self.archivesspace_instance_key}/#{self.repository_key}-#{resource_key}-folio.marc"
  end
end
