class InitialSchema < ActiveRecord::Migration
  def up
    create_table :users do |t|
      t.string :first_name,          :limit => 30
      t.string :last_name,           :limit => 30
      t.string :initials,            :limit => 2
      t.string :google_plus_user_id, :limit => 30
      t.timestamps
    end

    execute "insert into users (
      first_name,
      last_name,
      initials,
      google_plus_user_id,
      created_at,
      updated_at
    ) values (
      'Daniel',
      'Stutzman',
      'DS',
      '112826277336975923063',
      date('now'),
      date('now')
    );"

    create_table :attempts do |t|
      t.integer :task_id, :null => false
      t.integer :user_id, :null => false
      t.string  :status,  :limit => 20, :null => false
      t.timestamps
    end
  end

  def down
    drop_table :users
    drop_table :attempts
  end
end
