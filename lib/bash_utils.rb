module BashUtils
  TEAMVIEWER_PROC = 'TeamViewer_Desk'.freeze
  XSCREENSAVER_COMMAND = 'xscreensaver-command -watch'.freeze

  def self.teamviewer_session?
    `ps cax | grep #{TEAMVIEWER_PROC}` != ''
  end

  def self.notify(text)
    `notify-send -i go-home -t 7200000 "#{text}"`
  end

  def self.watch_xscreensaver_command
    IO.popen(XSCREENSAVER_COMMAND).each do |line|
      yield(line.chomp)
    end
  end
end
