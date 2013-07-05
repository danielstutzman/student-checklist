class AddWeeks < ActiveRecord::Migration
  def up
    create_table :weeks do |t|
      t.string  :label
      t.string  :summary
      t.string  :details
      t.date    :begin_date
      t.date    :end_date
    end
  end

  def down
    drop_table :weeks
  end
end
