# == Schema Information
#
# Table name: business_hour_breaks
#
#  id            :bigint           not null, primary key
#  day_of_week   :integer          not null
#  end_hour      :integer          not null
#  end_minutes   :integer          default(0), not null
#  message       :string           default(""), not null
#  start_hour    :integer          not null
#  start_minutes :integer          default(0), not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  account_id    :bigint
#  inbox_id      :bigint           not null
#
# Indexes
#
#  index_business_hour_breaks_on_account_id                (account_id)
#  index_business_hour_breaks_on_inbox_id_and_day_of_week  (inbox_id,day_of_week)
#
class BusinessHourBreak < ApplicationRecord
  belongs_to :inbox

  before_save :assign_account

  validates :day_of_week, presence: true, inclusion: 0..6
  validates :start_hour, :end_hour, presence: true, inclusion: 0..23
  validates :start_minutes, :end_minutes, presence: true, inclusion: 0..59
  validates :message, length: { maximum: Limits::OUT_OF_OFFICE_MESSAGE_MAX_LENGTH }
  validate :end_after_start

  # `time` is expected to already be in the inbox timezone
  def active_at?(time)
    return false unless time.to_date.wday == day_of_week

    start_time = time.change(hour: start_hour, min: start_minutes)
    end_time = time.change(hour: end_hour, min: end_minutes)
    time.between?(start_time, end_time)
  end

  def schedule_entry
    {
      'id' => id,
      'day_of_week' => day_of_week,
      'start_hour' => start_hour,
      'start_minutes' => start_minutes,
      'end_hour' => end_hour,
      'end_minutes' => end_minutes,
      'message' => message
    }
  end

  private

  def assign_account
    self.account_id = inbox.account_id
  end

  def end_after_start
    return if start_hour.blank? || end_hour.blank?
    return if (end_hour * 60 + end_minutes.to_i) > (start_hour * 60 + start_minutes.to_i)

    errors.add(:end_hour, 'must be after the start time')
  end
end
