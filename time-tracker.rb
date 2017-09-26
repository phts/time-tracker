#!/usr/bin/env ruby

require 'optparse'
require 'time'
require_relative 'lib/date_time_utils'

options = OptionParser.new do |opts|
  opts.banner = "Usage: #{opts.program_name} [options] REPORT_FILE"

  opts.on('-d', '--dynamic',
          'Use dynamic working day limit. Not supported for --genmon.') do
    @dynamic = true
  end

  opts.on('--genmon', 'Print current progress for xfce4-genmon-plugin') do
    @genmon = true
  end

  opts.on('-h', '--help', 'Show this message') do
    puts opts
    exit
  end

  opts.on('--initial-started=time',
          'Set initial "Started" time (HH:MM)') do |time|
    @initial_first_unblank = Time.strptime(time, '%H:%M')
  end

  opts.on('--initial-total-per-week=time',
          'Set initial "Total per week" time (HH:MM)') do |time|
    @initial_total_per_week = DateTimeUtils.to_seconds(time)
  end

  opts.on('-m', '--message=text',
          'Set a message of the "Go home" notification') do |text|
    @notification = text
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

require_relative 'lib/time_tracker'
time_tracker = TimeTracker.new(REPORT_FILE,
                               dynamic: @dynamic,
                               initial_first_unblank: @initial_first_unblank,
                               initial_total_per_week: @initial_total_per_week,
                               notification: @notification)

if @genmon
  require_relative 'lib/genmon'
  puts Genmon.new(time_tracker.current_time_file).progress
  exit
end

if @verbose
  time_tracker.on :new_xscreensaver_command do |data|
    puts "#{data[:command]} #{data[:time]}"
    puts "teamviewer_session? == #{data[:teamviewer_session?]} || "\
         '@was_unlocked_by_teamviewer == '\
         "#{data[:was_unlocked_by_teamviewer].inspect} || "\
         "@was_locked == #{data[:was_locked].inspect}"
  end
  time_tracker.on :lock do |data|
    puts "last_lock = #{data[:last_lock]}"
  end
  time_tracker.on :new_day do |data|
    puts 'new day'
    puts "first_unblank = #{data[:first_unblank]}"
  end
  time_tracker.on :new_week do
    puts 'new week'
  end
  time_tracker.on :fix_first_week_day do |data|
    puts "remaining working days of a week = #{data[:actual_working_days]}"
  end
  time_tracker.on :fix_days_gap do |data|
    puts "skip day gap: #{data[:days_gap]}"
    puts "actual working days of a week = #{data[:actual_working_days]}"
  end
end

time_tracker.start_notifications
time_tracker.run
