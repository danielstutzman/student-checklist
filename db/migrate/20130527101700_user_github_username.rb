class UserGithubUsername < ActiveRecord::Migration
  def up
    add_column :users, :github_username, :string
  end

  def down
    drop_column :users, :github_username
  end
end
