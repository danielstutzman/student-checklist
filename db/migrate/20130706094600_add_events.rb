class AddEvents < ActiveRecord::Migration
  def up
    create_table :events do |t|
      t.date    :date
      t.integer :hour
      t.string  :details
      t.string  :more_info_url
    end
  end

  def down
    drop_table :events
  end
end
