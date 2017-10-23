class ScreenNotifier
  DEFAULT_TEXT = 'Go home!'.freeze

  def initialize(text = nil)
    @text = text || DEFAULT_TEXT
  end

  def notify
    `notify-send -i go-home -t 7200000 "#{@text}"`
  end
end
