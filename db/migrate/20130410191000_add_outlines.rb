class AddOutlines < ActiveRecord::Migration
  def up
    create_table :outlines do |t|
      t.date   :date
      t.string :year,  :limit => 4
      t.string :month, :limit => 3
      t.string :day,   :limit => 2
      t.text   :text
      t.timestamps
    end
  end

  def down
    drop_table :outlines
  end
end
