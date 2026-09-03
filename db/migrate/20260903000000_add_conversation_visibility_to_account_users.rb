class AddConversationVisibilityToAccountUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :account_users, :conversation_visibility, :integer, default: 0, null: false
  end
end
