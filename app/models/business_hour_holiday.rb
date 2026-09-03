# == Schema Information
#
# Table name: business_hour_holidays
#
#  id             :bigint           not null, primary key
#  end_hour       :integer
#  end_minutes    :integer
#  holiday_date   :date             not null
#  message        :string           default(""), not null
#  repeats_yearly :boolean          default(FALSE), not null
#  start_hour     :integer
#  start_minutes  :integer
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  account_id     :bigint
#  inbox_id       :bigint           not null
#
# Indexes
#
#  index_business_hour_holidays_on_account_id                 (account_id)
#  index_business_hour_holidays_on_inbox_id_and_holiday_date  (inbox_id,holiday_date)
#
class BusinessHourHoliday < ApplicationRecord
  belongs_to :inbox

  before_save :assign_account

  validates :holiday_date, presence: true
  validates :message, length: { maximum: Limits::OUT_OF_OFFICE_MESSAGE_MAX_LENGTH }
  validates :start_hour, :end_hour, inclusion: 0..23, allow_nil: true
  validates :start_minutes, :end_minutes, inclusion: 0..59, allow_nil: true
  validate :partial_day_range

  # closed the whole day unless a specific window is set
  def all_day?
    start_hour.nil? || end_hour.nil?
  end

  def falls_on?(date)
    return true if holiday_date == date
    return false unless repeats_yearly?

    holiday_date.month == date.month && holiday_date.day == date.day
  end

  # `time` is expected to already be in the inbox timezone
  def active_at?(time)
    return false unless falls_on?(time.to_date)
    return true if all_day?

    start_time = time.change(hour: start_hour, min: start_minutes.to_i)
    end_time = time.change(hour: end_hour, min: end_minutes.to_i)
    time.between?(start_time, end_time)
  end

  def schedule_entry
    {
      'id' => id,
      'holiday_date' => holiday_date.iso8601,
      'repeats_yearly' => repeats_yearly,
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

  def partial_day_range
    return if all_day?
    return if (end_hour * 60 + end_minutes.to_i) > (start_hour * 60 + start_minutes.to_i)

    errors.add(:end_hour, 'must be after the start time')
  end
end
