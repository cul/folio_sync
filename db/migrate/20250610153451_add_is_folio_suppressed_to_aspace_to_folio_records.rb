class AddIsFolioSuppressedToAspaceToFolioRecords < ActiveRecord::Migration[8.0]
  def change
    add_column :aspace_to_folio_records, :is_folio_suppressed, :boolean, default: false, null: false
  end
end
