class AddExercises < ActiveRecord::Migration
  def up
    create_table :exercises do |t|
      t.integer :num
      t.text    :yaml
      t.timestamps
    end
  end

  def down
    drop_table :exercises
  end
end
