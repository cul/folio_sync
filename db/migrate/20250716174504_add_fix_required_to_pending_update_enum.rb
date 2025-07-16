class AddFixRequiredToPendingUpdateEnum < ActiveRecord::Migration[8.0]
  def change
    # No database changes needed - adding a new value "fix_required" (3) to the existing integer enum
    # Existing records will not be affected as they retain their current values
  end
end
