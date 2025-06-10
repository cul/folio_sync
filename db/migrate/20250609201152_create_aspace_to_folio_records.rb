class CreateAspaceToFolioRecords < ActiveRecord::Migration[8.0]
  def change
    create_table :aspace_to_folio_records do |t|
      t.string :archivesspace_instance_key, null: false
      t.integer :repository_id, null: false
      t.integer :resource_id, null: false
      t.string :folio_hrid
      t.integer :pending_update, default: 1 # Defaults to "to_folio"
      t.boolean :is_folio_suppressed, default: false, null: false

      t.timestamps
    end

    add_index :aspace_to_folio_records, [:archivesspace_instance_key, :repository_id, :resource_id], unique: true,
                                                                                                     name: 'resource_uri'
    add_index :aspace_to_folio_records, :folio_hrid, unique: true
    add_index :aspace_to_folio_records, :pending_update
  end
end
