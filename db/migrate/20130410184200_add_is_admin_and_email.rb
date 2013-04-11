class AddIsAdminAndEmail < ActiveRecord::Migration
  def up
    add_column :users, :is_admin, :boolean, :null => false, :default => false
    add_column :users, :email, :string
  end

  def down
    drop_column :users, :is_admin
    drop_column :users, :email
  end
end
