class ScreenNotifier
  DEFAULT_TEXT = 'Go home!'.freeze

  def initialize(text = DEFAULT_TEXT)
    @text = text
  end

  def notify
    `notify-send -i go-home -t 7200000 "#{@text}"`
  end
end
