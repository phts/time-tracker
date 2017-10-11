require_relative 'date_time_utils'

class CurrentTime
  def initialize(file_name)
    @file_name = file_name
  end

  def value
    File.read(@file_name).strip
  end

  def value=(val)
    File.open(@file_name, 'w') do |file|
      file.puts(DateTimeUtils.time_delta_str(val).to_s)
    end
  end
end
