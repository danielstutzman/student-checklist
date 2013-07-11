class AddOutlinesCategory < ActiveRecord::Migration
  def up
    add_column :outlines, :category, :string
    execute "update outlines set category = 'class'"
  end

  def down
    remove_column :outlines, :category
  end
end
