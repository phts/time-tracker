require_relative 'date_time_utils'

class FileReporter
  def initialize(report_file)
    @report_file = report_file
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
end
