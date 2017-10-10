require 'time'
require 'watchable'
require_relative 'config'
require_relative 'date_time_utils'

XSCREENSAVER_COMMAND = 'xscreensaver-command -watch'.freeze
TEAMVIEWER_PROC = 'TeamViewer_Desk'.freeze

class TimeTracker
  include Watchable

  attr_reader :current_time_file

  def initialize(report_file, options)
    @report_file = report_file
    @notification = options[:notification] || 'Go home!'
    @dynamic = options[:dynamic]

    @last_lock = Time.now
    @first_unblank = options[:initial_first_unblank] || @last_lock
    @current_week = DateTimeUtils.week_number(@last_lock)

    if options[:initial_total_per_week]
      @total_per_week = options[:initial_total_per_week]
      @limit_per_week = Config::WORKING_LIMIT_PER_WEEK
    else
      @total_per_week = 0
      fix_first_week_day
    end
    @current_time_file = "#{@report_file}.current"
  end

  def run
    print_started(@first_unblank)
    IO.popen(XSCREENSAVER_COMMAND).each do |line|
      process_line(line.chomp)
    end
  end

  def start_notifications
    Thread.fork do
      loop do
        process_notifications_loop
        sleep Config::REFRESH_CURRENT_TIME_INTERVAL
      end
    end
  end

  private

  def process_notifications_loop
    delta = Time.now - @first_unblank
    File.open(@current_time_file, 'w') do |file|
      file.puts(DateTimeUtils.time_delta_str(delta).to_s)
    end
    if delta >= (lim = today_limit) &&
       delta < lim + Config::REFRESH_CURRENT_TIME_INTERVAL
      notify(@notification)
    end
  end

  def process_line(line)
    fire :new_xscreensaver_command,
         command: line.split.first,
         time: Time.now,
         teamviewer_session?: teamviewer_session?,
         was_locked: @was_locked,
         was_unlocked_by_teamviewer: @was_unlocked_by_teamviewer

    if line['LOCK']
      process_lock
    elsif line['UNBLANK']
      process_unblank
    end
  end

  def process_lock
    unless teamviewer_session? || @was_unlocked_by_teamviewer
      @last_lock = Time.now
      fire :lock,
           last_lock: @last_lock
    end
    @was_unlocked_by_teamviewer = nil
    @was_locked = true
  end

  def process_unblank
    return unless @was_locked
    if teamviewer_session?
      @was_unlocked_by_teamviewer = true
      return
    end
    process_new_day if new_day?(Time.now)
    process_new_week if new_week?(Time.now)
    @was_locked = nil
  end

  def process_new_day
    @total_per_week += @last_lock - @first_unblank
    print_finished(@first_unblank, @last_lock, @total_per_week)
    @first_unblank = Time.now
    print_started(@first_unblank)
    fix_days_gap unless new_week?(Time.now)
    fire :new_day,
         first_unblank: @first_unblank
  end

  def process_new_week
    @total_per_week = 0
    @current_week = DateTimeUtils.week_number(Time.now)
    fix_first_week_day
    fire :new_week
  end

  def teamviewer_session?
    `ps cax | grep #{TEAMVIEWER_PROC}` != ''
  end

  def notify(text)
    `notify-send -i go-home -t 7200000 "#{text}"`
  end

  def print_started(first_unblank)
    first_unblank_str = first_unblank.strftime('%H:%M')
    date_str = first_unblank.strftime('%d.%m')
    File.open(@report_file, 'a') do |file|
      file.write("#{date_str}    Started: #{first_unblank_str}    ")
    end
  end

  def print_finished(first_unblank, last_lock, total_per_week)
    last_lock_str = last_lock.strftime('%H:%M')
    delta_str = DateTimeUtils.time_delta_str(last_lock, first_unblank)
    total_per_week_str = DateTimeUtils.time_delta_str(total_per_week)
    File.open(@report_file, 'a') do |file|
      file.puts("Finished: #{last_lock_str}    "\
                "Delta: #{delta_str}    "\
                "Total per week: #{total_per_week_str}")
    end
  end

  def today_limit
    return Config::WORKING_DAY_IN_SECONDS unless @dynamic

    days_to_weekend = 6 - @first_unblank.wday
    (@limit_per_week - @total_per_week).round / days_to_weekend
  end

  def new_day?(date)
    date.strftime('%Y-%m-%d') != @last_lock.strftime('%Y-%m-%d')
  end

  def new_week?(date)
    DateTimeUtils.week_number(date) != @current_week
  end

  def fix_first_week_day
    days_to_weekend = 6 - @first_unblank.wday
    @limit_per_week = Config::WORKING_DAY_IN_SECONDS * days_to_weekend
    fire :fix_first_week_day,
         actual_working_days: @limit_per_week / Config::WORKING_DAY_IN_SECONDS
  end

  def fix_days_gap
    days_gap = @first_unblank.wday - @last_lock.wday - 1
    @limit_per_week -= Config::WORKING_DAY_IN_SECONDS * days_gap
    return unless days_gap > 0

    fire :fix_days_gap,
         actual_working_days: @limit_per_week / Config::WORKING_DAY_IN_SECONDS,
         days_gap: days_gap
  end
end
