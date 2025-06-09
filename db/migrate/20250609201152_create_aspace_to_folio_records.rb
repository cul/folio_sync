class CreateAspaceToFolioRecords < ActiveRecord::Migration[8.0]
  def change
    create_table :aspace_to_folio_records do |t|
      t.string :archivesspace_instance_key
      t.integer :repository_id
      t.integer :resource_id
      t.string :folio_hrid
      t.integer :pending_update

      t.timestamps
    end
  end
end
