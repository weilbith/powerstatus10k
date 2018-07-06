#!/bin/bash
#
# PowerStatus10k segment.
# This segment displays the current sound output status.
# On the top level it differs between muted and not.
# Furthermore it classifies the volume and differ the icon by this.

# Implement the interface function to get the current state.
#
function getState_sound {
  # Check if the sound is muted.
  if [[ $(pactl list sinks | grep Mute) = *yes* ]] ; then
   STATE="%{F${SOUND_COLOR_MUTED}}${SOUND_ICON_MUTED}"

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

    STATE="${icon} ${volume}%"
  fi
}
