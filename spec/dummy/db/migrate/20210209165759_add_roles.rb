class AddRoles < ActiveRecord::Migration[6.1]
  def change
    create_table :roles, id: :uuid do |t|
      t.text :user_id, null: false
      t.text :name, null: false
      t.timestamps
    end
  end
end
