class CreateBusinessHourBreaks < ActiveRecord::Migration[7.2]
  def change
    create_table :business_hour_breaks, if_not_exists: true do |t|
      t.references :inbox, null: false, foreign_key: true
      t.bigint :account_id
      t.integer :day_of_week, null: false
      t.integer :start_hour, null: false
      t.integer :start_minutes, null: false, default: 0
      t.integer :end_hour, null: false
      t.integer :end_minutes, null: false, default: 0
      t.string :message, null: false, default: ''
      t.timestamps
    end

    add_index :business_hour_breaks, %i[inbox_id day_of_week], if_not_exists: true
    add_index :business_hour_breaks, :account_id, if_not_exists: true
  end
end
