# frozen_string_literal: true

module OutOfOffisable
  extend ActiveSupport::Concern

  OFFISABLE_ATTRS = %w[day_of_week closed_all_day open_hour open_minutes close_hour close_minutes open_all_day].freeze
  BREAK_ATTRS = %w[day_of_week start_hour start_minutes end_hour end_minutes message].freeze
  HOLIDAY_ATTRS = %w[holiday_date repeats_yearly start_hour start_minutes end_hour end_minutes message].freeze
  DEFAULT_WORKING_HOURS = [
    { day_of_week: 0, closed_all_day: true, open_all_day: false },
    { day_of_week: 1, open_hour: 9, open_minutes: 0, close_hour: 17, close_minutes: 0, open_all_day: false },
    { day_of_week: 2, open_hour: 9, open_minutes: 0, close_hour: 17, close_minutes: 0, open_all_day: false },
    { day_of_week: 3, open_hour: 9, open_minutes: 0, close_hour: 17, close_minutes: 0, open_all_day: false },
    { day_of_week: 4, open_hour: 9, open_minutes: 0, close_hour: 17, close_minutes: 0, open_all_day: false },
    { day_of_week: 5, open_hour: 9, open_minutes: 0, close_hour: 17, close_minutes: 0, open_all_day: false },
    { day_of_week: 6, closed_all_day: true, open_all_day: false }
  ].map(&:freeze).freeze

  included do
    has_many :working_hours, dependent: :destroy_async
    has_many :business_hour_breaks, dependent: :destroy_async
    has_many :business_hour_holidays, dependent: :destroy_async
    after_create :create_default_working_hours
  end

  def out_of_office?
    out_of_office_context.present?
  end

  def working_now?
    !out_of_office?
  end

  # Returns { reason:, message: } describing the current closure, or nil when open.
  # Priority: a matching holiday, then a matching intra-day break, then the weekly schedule.
  def out_of_office_context
    return nil unless working_hours_enabled?

    now = Time.zone.now.in_time_zone(timezone)

    holiday = business_hour_holidays.detect { |entry| entry.active_at?(now) }
    return { reason: 'holiday', message: holiday.message } if holiday

    break_period = business_hour_breaks.detect { |entry| entry.active_at?(now) }
    return { reason: 'break', message: break_period.message } if break_period

    return { reason: 'off_hours', message: out_of_office_message } if working_hours.today.closed_now?

    nil
  end

  # The message to auto-reply with while out of office, or nil when there is none.
  def out_of_office_response_message
    context = out_of_office_context
    return if context.nil?

    context[:message].presence
  end

  def weekly_schedule
    working_hours.sort_by(&:day_of_week).map do |wh|
      {
        'day_of_week' => wh.day_of_week,
        'closed_all_day' => wh.closed_all_day,
        'open_hour' => wh.open_hour,
        'open_minutes' => wh.open_minutes,
        'close_hour' => wh.close_hour,
        'close_minutes' => wh.close_minutes,
        'open_all_day' => wh.open_all_day
      }
    end
  end

  def breaks_schedule
    business_hour_breaks
      .sort_by { |entry| [entry.day_of_week, entry.start_hour, entry.start_minutes] }
      .map(&:schedule_entry)
  end

  def holidays_schedule
    business_hour_holidays.sort_by(&:holiday_date).map(&:schedule_entry)
  end

  # accepts an array of hashes similiar to the format of weekly_schedule
  #  [
  #    { "day_of_week"=>1,
  #      "closed_all_day"=>false,
  #      "open_hour"=>9,
  #      "open_minutes"=>0,
  #      "close_hour"=>17,
  #      "close_minutes"=>0,
  #      "open_all_day=>false" },...]
  def update_working_hours(params)
    ActiveRecord::Base.transaction do
      params.each do |working_hour|
        working_hours.find_by(day_of_week: working_hour['day_of_week']).update(working_hour.slice(*OFFISABLE_ATTRS))
      end
    end
  end

  # full replace: accepts an array of hashes with the keys in BREAK_ATTRS
  def update_business_hour_breaks(params)
    ActiveRecord::Base.transaction do
      business_hour_breaks.destroy_all
      Array(params).each { |entry| business_hour_breaks.create!(entry.slice(*BREAK_ATTRS)) }
    end
  end

  # full replace: accepts an array of hashes with the keys in HOLIDAY_ATTRS
  def update_business_hour_holidays(params)
    ActiveRecord::Base.transaction do
      business_hour_holidays.destroy_all
      Array(params).each { |entry| business_hour_holidays.create!(entry.slice(*HOLIDAY_ATTRS)) }
    end
  end

  private

  def create_default_working_hours
    DEFAULT_WORKING_HOURS.each { |attributes| working_hours.create!(attributes) }
  end
end
