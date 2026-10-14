# One JSON column for every per-user setting, so adding the next one is a
# store_accessor on User rather than another migration.
class AddPreferencesToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :preferences, :json, null: false, default: {}
  end
end
