class AddPosts < ActiveRecord::Migration[6.1]
  def change
    create_table :posts, id: :uuid do |t|
      t.text :name
      t.text :body
      t.timestamps
    end
  end
end
