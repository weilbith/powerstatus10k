#!/bin/bash
#
# PowerStatus10k segment.
# This segment displays the current battery status.
# The segment differ between charging and discharging.
# The battery capacity is classified to display different icons representing the current
# capacity level.

# Implement the interface function to get the current state.
#
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
    charging=$(cat "${BATTERY_PATH_CHARGE}") # Get the additional icon.
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

  # Set the color for the critical or full state.
  local color

  if [ ! $charging -eq 1 -a $capacity -le $BATTERY_CRITICAL_THRESHOLD ] ; then
    color="%{F${BATTERY_CRITICAL_COLOR}}"

  elif [ $charging -eq 1 -a $capacity -ge $BATTERY_FULL_THRESHOLD ] ; then
    color="%{F${BATTERY_FULL_COLOR}}"
  fi


  # Build the status string.
  echo "${color}${icon} ${capacity}%"
  return
}
