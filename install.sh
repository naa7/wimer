#!/bin/bash

# Make the script executable
chmod +x wimer.sh

# Copy the script to /usr/bin/
sudo cp wimer.sh /usr/bin/wimer

# Copy `work_timer.desktop` to `/usr/share/applications/`
sudo cp wimer.desktop /usr/share/applications/

# Copy `wimer_alarm.wav` to `/usr/share/sounds/wimer`
sudo mkdir /usr/share/sounds/wimer && sudo cp wimer_alarm.wav /usr/share/sounds/wimer/

# Copy `wimer.png` to `/usr/share/icons/wimer`
sudo mkdir /usr/share/icons/wimer && sudo cp wimer.png /usr/share/icons/wimer/