require 'time'
require 'watchable'
require_relative 'config'
require_relative 'bash_utils'
require_relative 'date_time_utils'

class TimeTracker
  include Watchable

  def initialize(options)
    @dont_ignore_teamviewer = options[:dont_ignore_teamviewer]
    @dynamic = options[:dynamic]
    @last_lock = Time.now
    @first_unblank = options[:initial_first_unblank] || @last_lock
    @current_week = DateTimeUtils.week_number(@last_lock)
    @total_per_week = options[:initial_total_per_week] || 0
  end

  def run
    fire :run,
         first_unblank: @first_unblank
    init_limit_per_week
    start_notifications
    start_refresh_current_time
    BashUtils.watch_xscreensaver_command do |line|
      process_line(line)
    end
  end

  private

  def start_notifications
    Thread.fork do
      loop do
        process_notifications_loop
        sleep Config::REFRESH_CURRENT_TIME_INTERVAL
      end
    end
  end

  def start_refresh_current_time
    Thread.fork do
      loop do
        delta = Time.now - @first_unblank
        fire :refresh_current_time,
             current_time_sec: delta
        sleep Config::REFRESH_CURRENT_TIME_INTERVAL
      end
    end
  end

  def process_notifications_loop
    delta = Time.now - @first_unblank
    lim = today_limit
    if delta >= lim &&
       delta < lim + Config::REFRESH_CURRENT_TIME_INTERVAL
      fire :go_home
    end
  end

  def process_line(line)
    fire :new_xscreensaver_command,
         command: line.split.first,
         time: Time.now,
         teamviewer_session?: BashUtils.teamviewer_session?,
         was_locked: @was_locked,
         was_unlocked_by_teamviewer: @was_unlocked_by_teamviewer

    if line['LOCK']
      process_lock
    elsif line['UNBLANK']
      process_unblank
    end
  end

  def process_lock
    unless ignored_due_to_teamviewer_session?
      @last_lock = Time.now
      fire :lock,
           last_lock: @last_lock
    end
    @was_unlocked_by_teamviewer = nil
    @was_locked = true
  end

  def process_unblank
    return unless @was_locked
    if ignored_due_to_teamviewer_session?
      @was_unlocked_by_teamviewer = true
      return
    end
    process_new_day if new_day?(Time.now)
    process_new_week if new_week?(Time.now)
    @was_locked = nil
  end

  def process_new_day
    @total_per_week += @last_lock - @first_unblank
    fire :before_new_day,
         first_unblank: @first_unblank,
         last_lock: @last_lock,
         total_per_week: @total_per_week

    @first_unblank = Time.now
    fix_days_gap unless new_week?(Time.now)
    fire :new_day,
         first_unblank: @first_unblank
  end

  def process_new_week
    @total_per_week = 0
    @current_week = DateTimeUtils.week_number(Time.now)
    init_limit_per_week
    fire :new_week
  end

  def ignored_due_to_teamviewer_session?
    return false if @dont_ignore_teamviewer
    BashUtils.teamviewer_session? || @was_unlocked_by_teamviewer
  end

  def today_limit
    return Config::WORKING_DAY_IN_SECONDS unless @dynamic

    (@limit_per_week - @total_per_week).round / remaining_days_before_weekend
  end

  def remaining_days_before_weekend
    Config::WORKING_DAYS_PER_WEEK - @first_unblank.wday + 1
  end

  def actual_working_days
    @limit_per_week / Config::WORKING_DAY_IN_SECONDS
  end

  def to_working_days(seconds)
    whole_days, rest = seconds.divmod(Config::WORKING_DAY_IN_SECONDS)
    return whole_days if rest < Config::MINIMAL_WORKING_DAY_IN_SECONDS
    whole_days + 1
  end

  def new_day?(date)
    date.strftime('%Y-%m-%d') != @last_lock.strftime('%Y-%m-%d')
  end

  def new_week?(date)
    DateTimeUtils.week_number(date) != @current_week
  end

  def init_limit_per_week
    self.limit_per_week =
      Config::WORKING_DAY_IN_SECONDS *
      (remaining_days_before_weekend + to_working_days(@total_per_week))
  end

  def fix_days_gap
    days_gap = @first_unblank.wday - @last_lock.wday - 1
    return unless days_gap > 0

    days_gap_sec = Config::WORKING_DAY_IN_SECONDS * days_gap
    self.limit_per_week = @limit_per_week - days_gap_sec
    fire :fix_days_gap,
         days_gap: days_gap
  end

  def limit_per_week=(value)
    @limit_per_week = value
    fire :set_limit_per_week,
         actual_working_days: actual_working_days
  end
end
