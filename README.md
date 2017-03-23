# Working Time Tracker

A simple script to track how much time you spend near the computer at the office.

## Requirements

The script uses `xscreensaver-command -watch` output so `xscreensaver` is required as a screen locking framework.
Notifications are shown by `notify-send`.
And [Ruby](https://www.ruby-lang.org/en/) (tested on v2.2.3) is needed to be able to run the script.

Also it assumes that you do not work at nights and do not turn off your PC.

## Usage

This script should be run during the whole session so it can me executed from *.profile* file or as a service.

To run the script from terminal emulator:

    time-tracker.rb ~/time.txt

It generates a report file (in this case *~/time.txt*), for example:

    11.01    Started: 09:34    Finished: 17:35    Delta: 08:00    Total per week: 08:00
    12.01    Started: 10:35    Finished: 18:29    Delta: 07:54    Total per week: 15:54
    13.01    Started: 09:01    Finished: 17:20    Delta: 08:19    Total per week: 24:13

Also it creates a file (*~/time.txt.current*) which contains working time for the current day.
You can use this file wherever you want.
And it is used by Generic Monitor plugin.

For more information about options:

    time-tracker.rb --help

## Generic Monitor plugin

Additionally the script can be used with [dnschneid/xfce4-genmon-plugin](https://github.com/dnschneid/xfce4-genmon-plugin) to display a progress bar on the panel.

    time-tracker.rb --genmon ~/time.txt

## Notification

There is a notification if you have already been 8 hours at the office - it's time to go home.

## TeamViewer

This script doesn't treat TeamViewer sessions as working time.
So any screen lock/unlock under TeamViewer will be ignored and will not be taken into account.
