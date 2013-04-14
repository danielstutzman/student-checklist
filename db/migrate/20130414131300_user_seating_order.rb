class UserSeatingOrder < ActiveRecord::Migration
  def up
    add_column :users, :seating_order, :integer
  end

  def down
    remove_column :users, :seating_order
  end
end
