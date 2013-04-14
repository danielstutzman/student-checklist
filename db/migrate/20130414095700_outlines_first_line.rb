class OutlinesFirstLine < ActiveRecord::Migration
  def up
    add_column :outlines, :first_line, :string
  end

  def down
    remove_column :outlines, :first_line
  end
end
