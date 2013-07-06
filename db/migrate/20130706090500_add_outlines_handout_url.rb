class AddOutlinesHandoutUrl < ActiveRecord::Migration
  def up
    add_column :outlines, :handout_url, :string
  end

  def down
    remove_column :outlines, :handout_url
  end
end
