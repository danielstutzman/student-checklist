class AddExercises < ActiveRecord::Migration
  def up
    create_table :exercises do |t|
      t.string :task_id
      t.text   :yaml
      t.timestamps
    end
    add_index :exercises, :task_id, :unique => true
  end

  def down
    drop_table :exercises
  end
end
