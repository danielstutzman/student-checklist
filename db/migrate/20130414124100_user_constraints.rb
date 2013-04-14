class UserConstraints < ActiveRecord::Migration
  def up
    add_index :users, :initials,            :unique => true
    add_index :users, :google_plus_user_id, :unique => true
    add_index :users, :email,               :unique => true
  end

  def down
    drop_index :users, :initials
    drop_index :users, :google_plus_user_id
    drop_index :users, :email
  end
end
