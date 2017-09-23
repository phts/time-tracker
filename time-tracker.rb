#!/usr/bin/env ruby

require 'optparse'
require 'time'
require_relative 'lib/date_time_utils'

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
    @initial_total_per_week = DateTimeUtils.to_seconds(time)
  end

  opts.on('-m', '--message=text', 'Set a message of the "Go home" notification') do |text|
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
time_tracker = TimeTracker.new(REPORT_FILE, {
  dynamic: @dynamic,
  initial_first_unblank: @initial_first_unblank,
  initial_total_per_week: @initial_total_per_week,
  notification: @notification,
  verbose: @verbose,
})

if @genmon
  require_relative 'lib/genmon'
  puts Genmon.new(time_tracker.current_time_file).progress
  exit
end

time_tracker.start_notifications
time_tracker.run
