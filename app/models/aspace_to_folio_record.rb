# frozen_string_literal: true

class AspaceToFolioRecord < ApplicationRecord
  enum :pending_update, { no_update: 0, to_folio: 1, to_aspace: 2 }

  validates :archivesspace_instance_key, presence: true
  validates :repository_key, presence: true
  validates :resource_key, presence: true
end
