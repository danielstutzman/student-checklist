class TaskIdNotNumeric < ActiveRecord::Migration
  def up
    change_column :attempts, :task_id, :string, :length => 4
  end

  def down
    change_column :attempts, :task_id, :integer
  end
end
