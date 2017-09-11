#!/usr/bin/env ruby

require 'optparse'
require 'time'

def to_seconds(time_str)
  spl_time = time_str.split(':').map{|s| s.to_i}
  raise ArgumentError.new('Time format should be HH:MM') unless spl_time.size == 2
  spl_time[0]*3600 + spl_time[1]*60
end

options = OptionParser.new do |opts|
  opts.banner = "Usage: #{opts.program_name} [options] REPORT_FILE"

  opts.on('-d', '--dynamic', 'Use dynamic working day limit. Not supported for --genmon.') do
    @dynamic = true
  end

  opts.on('--genmon', 'Print current progress for xfce4-genmon-plugin') do
    @genmon = true
  end

  opts.on( '-h', '--help', 'Show this message' ) do
    puts opts
    exit
  end

  opts.on('--initial-started=time', 'Set initial "Started" time (HH:MM)') do |time|
    @initial_first_unblank = Time.strptime(time, '%H:%M')
  end

  opts.on('--initial-total-per-week=time', 'Set initial "Total per week" time (HH:MM)') do |time|
    @initial_total_per_week = to_seconds(time)
  end

  opts.on('-m', '--message=text', 'Set a message of the "Go home" notification') do |text|
    @message = text
  end

  opts.on('--verbose', 'Print verbose information') do
    @verbose = true
  end
end

begin
  options.parse!
rescue OptionParser::ParseError
  puts options
  exit 1
end

REPORT_FILE = ARGV[-1]
unless REPORT_FILE
  puts options
  exit 1
end

CURRENT_TIME_FILE = "#{REPORT_FILE}.current"
REFRESH_CURRENT_TIME_INTERVAL = 59
WORKING_DAY_IN_HOURS = 8
WORKING_DAY_IN_SECONDS = WORKING_DAY_IN_HOURS*3600
WORKING_LIMIT_PER_WEEK = WORKING_DAY_IN_SECONDS*5

if @genmon
  current_time_str = File.read(CURRENT_TIME_FILE).strip
  current_time_sec = to_seconds(current_time_str)
  progress = 100 * current_time_sec / WORKING_DAY_IN_SECONDS

  started_time = Time.now - current_time_sec
  until_time = Time.now + (WORKING_DAY_IN_SECONDS-current_time_sec)
  tooltip = "Current:\t#{current_time_str}\n\nStarted:\t#{ started_time.strftime('%H:%M') }\nUntil:\t#{ until_time.strftime('%H:%M') }"
  puts "<bar>#{progress}</bar><tool>#{tooltip}</tool>"
  exit
end

XSCREENSAVER_COMMAND = 'xscreensaver-command -watch'
TEAMVIEWER_PROC = 'TeamViewer_Desk'
NOTIFICATION = @message || 'Go home!'

class Time
  def week_number
    self.strftime('%W').to_i
  end
end

def teamviewer_session?
  `ps cax | grep #{TEAMVIEWER_PROC}` != ''
end

def time_delta_str(t1_or_delta, t2 = nil)
  delta = t2.nil? ? t1_or_delta : t1_or_delta - t2
  mm, ss = delta.divmod(60)
  hh, mm = mm.divmod(60)
  sprintf("%02d:%02d", hh, mm)
end

def notify(text)
  `notify-send -i go-home -t 7200000 "#{text}"`
end

def print_started(first_unblank)
  first_unblank_str = first_unblank.strftime('%H:%M')
  date_str = first_unblank.strftime('%d.%m')
  File.open(REPORT_FILE, 'a') do |file|
    file.write("#{date_str}    Started: #{first_unblank_str}    ")
  end
end

def print_finished(first_unblank, last_lock, total_per_week)
  last_lock_str = last_lock.strftime('%H:%M')
  delta_str = time_delta_str(last_lock, first_unblank)
  total_per_week_str = time_delta_str(total_per_week)
  File.open(REPORT_FILE, 'a') do |file|
    file.puts("Finished: #{last_lock_str}    Delta: #{delta_str}    Total per week: #{total_per_week_str}")
  end
end

def verbose(text)
  return unless @verbose
  puts text
end

def today_limit
  return WORKING_DAY_IN_SECONDS unless @dynamic

  days_to_weekend = 6 - @first_unblank.wday
  (WORKING_LIMIT_PER_WEEK-@total_per_week).round / days_to_weekend
end

def new_day?(date)
  date.strftime('%Y-%m-%d') != @last_lock.strftime('%Y-%m-%d')
end

def new_week?(date)
  date.week_number != @current_week
end

@last_lock = Time.now
@first_unblank = @initial_first_unblank || @last_lock
@current_week = @last_lock.week_number
@total_per_week = @initial_total_per_week || 0

print_started(@first_unblank)

Thread.fork do
  loop do
    delta = Time.now - @first_unblank
    File.open(CURRENT_TIME_FILE, 'w') { |file| file.puts("#{time_delta_str(delta)}") }
    if delta >= (lim=today_limit) && delta < lim+REFRESH_CURRENT_TIME_INTERVAL
      notify(NOTIFICATION)
    end
    sleep REFRESH_CURRENT_TIME_INTERVAL
  end
end

IO.popen(XSCREENSAVER_COMMAND).each do |line|
  line = line.chomp
  verbose "#{line.split.first} #{Time.now}"
  verbose "teamviewer_session? == #{teamviewer_session?} || @was_unlocked_by_teamviewer == #{@was_unlocked_by_teamviewer.inspect} || @was_locked == #{@was_locked.inspect}"
  if line['LOCK']
    unless teamviewer_session? || @was_unlocked_by_teamviewer
      @last_lock = Time.now
      verbose "last_lock = #{@last_lock}"
    end
    @was_unlocked_by_teamviewer = nil
    @was_locked = true
  elsif line['UNBLANK']
    next unless @was_locked
    if teamviewer_session?
      @was_unlocked_by_teamviewer = true
      next
    end
    now = Time.now
    if new_day?(now)
      @total_per_week += @last_lock - @first_unblank
      print_finished(@first_unblank, @last_lock, @total_per_week)
      @first_unblank = now
      print_started(@first_unblank)
      verbose 'new day'
      verbose "first_unblank = #{@first_unblank}"
    end
    if new_week?(now)
      @total_per_week = 0
      @current_week = now.week_number
      verbose 'new week'
    end
    @was_locked = nil
  end
end
