class ExercisesOutlineId < ActiveRecord::Migration
  def up
    add_column :exercises, :outline_id, :integer
  end

  def down
    drop_column :exercises, :outline_id
  end
end
