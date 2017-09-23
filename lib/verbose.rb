class Verbose
  def initialize(enabled)
    @enabled = enabled
  end

  def log(text)
    return unless @enabled
    puts text
  end
end
