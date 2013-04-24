class UserIsStudent < ActiveRecord::Migration
  def up
    add_column :users, :is_student, :boolean
  end

  def down
    remove_column :users, :is_student
  end
end
