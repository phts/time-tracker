require_relative 'config'
require_relative 'date_time_utils'

class Genmon
  def initialize(current_time_str)
    @current_time_str = current_time_str
  end

  def progress
    current_time_sec = DateTimeUtils.to_seconds(@current_time_str)
    progress = 100 * current_time_sec / Config::WORKING_DAY_IN_SECONDS

    started_time = Time.now - current_time_sec
    until_time = Time.now + (Config::WORKING_DAY_IN_SECONDS - current_time_sec)
    tooltip = "Current:\t#{@current_time_str}\n\n"\
              "Started:\t#{started_time.strftime('%H:%M')}\n"\
              "Until:\t#{until_time.strftime('%H:%M')}"
    "<bar>#{progress}</bar><tool>#{tooltip}</tool>"
  end
end
