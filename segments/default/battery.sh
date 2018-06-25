#!/bin/bash

# Icons and their thresholds.
BATTERY_ICONS_CHARGING=("  " "  " "  " "  " "  ")
BATTERY_ICONS_DISCHARGING=(" " " " " " " " " ")
BATTERY_THRESHOLDS=(90 60 40 10 0)

# Paths
BATTERY_PATH_CHARGE='/sys/class/power_supply/AC/online'
BATTERY_PATH_CAPACITY='/sys/class/power_supply/BAT1/capacity'


function getState_battery {
  # Get the current capacity.
  capacity=0

  # Read the capacity file if available.
  if [[ -f "$BATTERY_PATH_CAPACITY" ]] ; then
    capacity=$(cat "${BATTERY_PATH_CAPACITY}")
  fi

  # Per default the battery is not charging.
  charging=0

  if [[ -f "$BATTERY_PATH_CHARGE" ]] ; then
    charging=$(cat "${BATTERY_PATH_CHARGE}")
  fi

  # Differ the icon list if charging.
  icon_list=("${BATTERY_ICONS_DISCHARGING[@]}") # Per default use the discharging list.
  
  if [[ $charging -eq 1 ]] ; then
    icon_list=("${BATTERY_ICONS_CHARGING[@]}")
  fi

  # Get the icon based on the current capacity.
  icon="${icon_list[0]}" # Use full battery per default. 

  for (( i=0; i<${#BATTERY_THRESHOLDS[@]}; i++ )) ; do
    threshold=${BATTERY_THRESHOLDS[i]}
      
    # Check if the capacity is higher than the threshold.
    if [[ $capacity -ge $threshold ]] ; then
      icon="${icon_list[i]}"
      break
    fi
  done

  # Build the status string.
  echo "${icon} ${capacity}%"
  return
}
