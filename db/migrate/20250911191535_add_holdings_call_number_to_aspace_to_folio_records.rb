class AddHoldingsCallNumberToAspaceToFolioRecords < ActiveRecord::Migration[8.0]
  def change
    add_column :aspace_to_folio_records, :holdings_call_number, :string
  end
end
