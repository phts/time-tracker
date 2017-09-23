module DateTimeUtils
  def self.to_seconds(time_str)
    spl_time = time_str.split(':').map{|s| s.to_i}
    raise ArgumentError.new('Time format should be HH:MM') unless spl_time.size == 2
    spl_time[0]*3600 + spl_time[1]*60
  end

  def self.week_number(time)
    time.strftime('%W').to_i
  end

  def self.time_delta_str(t1_or_delta, t2 = nil)
    delta = t2.nil? ? t1_or_delta : t1_or_delta - t2
    mm, ss = delta.divmod(60)
    hh, mm = mm.divmod(60)
    sprintf("%02d:%02d", hh, mm)
  end
end
