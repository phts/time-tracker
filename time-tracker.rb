#!/usr/bin/ruby

REPORT_FILE = ARGV[0]
unless REPORT_FILE
  puts 'An output file should be specified'
  exit 1
end

XSCREENSAVER_COMMAND = 'xscreensaver-command -watch'
TEAMVIEWER_PROC = 'TeamViewer_Desk'
CURRENT_TIME_FILE = "#{REPORT_FILE}.current"
REFRESH_CURRENT_TIME_INTERVAL = 59
WORKING_DAY_IN_HOURS = 8
WORKING_DAY_IN_SECONDS = WORKING_DAY_IN_HOURS*3600
NOTIFICATION = 'Go home! :)'

if ARGV.include?('--genmon')
  current_time_str = File.read(CURRENT_TIME_FILE).strip
  spl_time = current_time_str.split(':').map{|s| s.to_i}
  current_time_sec = spl_time[0]*3600 + spl_time[1]*60 + spl_time[2]
  progress = 100 * current_time_sec / WORKING_DAY_IN_SECONDS
  puts "<bar>#{progress}</bar><tool>#{current_time_str}</tool>"
  exit
end

def teamviewer_session?
  `ps cax | grep #{TEAMVIEWER_PROC}` != ''
end

def time_delta_str(t1_or_delta, t2 = nil)
  delta = t2.nil? ? t1_or_delta : t1_or_delta - t2
  Time.at(delta).utc.strftime('%H:%M:%S')
end

def notify(text)
  `zenity --info --text="#{text}"`
end

last_lock = first_unblank = Time.now

Thread.fork do
  loop do
    delta = Time.now - first_unblank
    File.open(CURRENT_TIME_FILE, 'w') { |file| file.puts("#{time_delta_str(delta)}") }
    if delta >= WORKING_DAY_IN_SECONDS && delta < WORKING_DAY_IN_SECONDS+REFRESH_CURRENT_TIME_INTERVAL
      notify(NOTIFICATION)
    end
    sleep REFRESH_CURRENT_TIME_INTERVAL
  end
end

IO.popen(XSCREENSAVER_COMMAND).each do |line|
  next if teamviewer_session?
  line = line.chomp
  if line['LOCK']
    last_lock = Time.now
  elsif line['UNBLANK']
    now = Time.now
    if now.day != last_lock.day # a new day started
      date_str = first_unblank.strftime('%d.%m')
      last_lock_str = last_lock.strftime('%H:%M')
      delta_str = time_delta_str(last_lock, first_unblank)

      first_unblank = now
      first_unblank_str = first_unblank.strftime('%H:%M')
      File.open(REPORT_FILE, 'a') do |file|
        file.puts("\tFinished: #{last_lock_str}\tDelta: #{delta_str}")
        file.write("#{date_str}\tStarted: #{first_unblank_str}")
      end
    end
  end
end
