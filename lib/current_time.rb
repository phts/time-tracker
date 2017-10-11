require_relative 'date_time_utils'

class CurrentTime
  def initialize(file_name)
    @file_name = file_name
  end

  def seconds
    DateTimeUtils.to_seconds(File.read(@file_name).strip)
  end

  def seconds=(val)
    File.open(@file_name, 'w') do |file|
      file.puts(DateTimeUtils.time_delta_str(val))
    end
  end
end
