# frozen_string_literal: true

class AspaceToFolioRecord < ApplicationRecord
  enum pending_update: { none: 0, to_folio: 1, to_aspace: 2 }

  validates :archivesspace_instance_key, presence: true
  validates :repository_id, presence: true
  validates :resource_id, presence: true

  # before_create :set_pending_update

  # def set_pending_update
  #   self.pending_update ||= :to_folio
  # end
end
