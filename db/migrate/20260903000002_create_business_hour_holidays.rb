class CreateBusinessHourHolidays < ActiveRecord::Migration[7.2]
  def change
    create_table :business_hour_holidays do |t|
      t.references :inbox, null: false, foreign_key: true
      t.bigint :account_id
      t.date :holiday_date, null: false
      t.boolean :repeats_yearly, null: false, default: false
      t.integer :start_hour
      t.integer :start_minutes
      t.integer :end_hour
      t.integer :end_minutes
      t.string :message, null: false, default: ''
      t.timestamps
    end

    add_index :business_hour_holidays, %i[inbox_id holiday_date]
    add_index :business_hour_holidays, :account_id
  end
end
