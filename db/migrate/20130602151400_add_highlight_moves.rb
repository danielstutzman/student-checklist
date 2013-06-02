class AddHighlightMoves < ActiveRecord::Migration
  def up
    create_table :highlight_moves do |t|
      t.integer   :outline_id
      t.integer   :num_desc
      t.timestamp :created_at
    end
    add_index :highlight_moves, :outline_id
  end

  def down
    drop_table :highlight_moves
  end
end
