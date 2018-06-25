#!/bin/bash

# Icons and their thresholds.
SOUND_ICON_MUTED="ﱝ"
SOUND_ICONS_LEVELS=("" "墳" " ")
SOUND_THRESHOLDS=(75 50 25 0)

function getState_sound {
  # Check if the sound is muted.
  if [[ $(pactl list sinks | grep Mute) = *yes* ]] ; then
   echo "${SOUND_ICON_MUTEDS}"
   return

  else 
    # Get the current volume.
    volume=$(pactl list sinks | grep '^[[:space:]]Volume:' | head -n $(( $SINK + 1 )) | tail -n 1 | sed -e 's,.* \([0-9][0-9]*\)%.*,\1,')

    # Get the icon based on the current volume.
    icon="${SOUND_ICONS_LEVELS[0]}" # Use full sound per default.

    for (( i=0; i<${#SOUND_THRESHOLDS[@]}; i++ )) ; do
      threshold=${SOUND_THRESHOLDS[i]}
        
      # Check if the volume is higher than the threshold.
      if [[ $volume -ge $threshold ]] ; then
        icon="${SOUND_ICONS_LEVELS[i]}"
        break
      fi
    done

    echo "${icon} ${volume}%"
  fi
}
