# frozen_string_literal: true

FactoryBot.define do
  factory :aspace_to_folio_record do
    transient do
      instance_keys { %w[instance1 instance2] }
      repository_keys { (1..50).to_a }
      resource_keys { (1..50).to_a }
    end

    archivesspace_instance_key { instance_keys.sample }
    repository_key { repository_keys.sample }
    resource_key { resource_keys.sample }
    pending_update { :no_update }
    is_folio_suppressed { false }
  end

  trait :with_folio_data do
    folio_hrid { "folio_hrid_#{SecureRandom.hex}" }
  end

  trait :ready_for_folio do
    pending_update { :to_folio }
  end

  trait :ready_for_aspace do
    pending_update { :to_aspace }
  end
end
