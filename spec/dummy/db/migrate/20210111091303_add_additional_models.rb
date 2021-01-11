class AddAdditionalModels < ActiveRecord::Migration[6.1]
  def change
    create_table :users, id: :uuid do |t|
      t.text :name
      t.timestamps
    end

    create_table :comments, id: :uuid do |t|
      t.text :post_id, null: false
      t.text :user_id, null: false
      t.text :body
      t.timestamps
    end

    create_table :likes, id: :uuid do |t|
      t.text :comment_id, null: false
      t.text :user_id, null: false
      t.timestamps
    end
  end
end
