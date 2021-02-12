class AddModeratingUserId < ActiveRecord::Migration[6.1]
  def change
    add_reference :comments, :moderating_user, type: :uuid, foreign_key: { to_table: :users }
  end
end
