#!/bin/bash

# Load the default and user configurations.
source $(dirname $0)/default.conf # Default values for all necessary variables.
source $(dirname $0)/custom.conf # Load after default values to be able to overwrite them.

# Load the segments.
source $(dirname $0)/segments.sh


# Define deviated variables.
[[ "$BOTTOM" = true ]] && BAR_BOTTOM_ARG="-b"


# Prepare the fifo.
rm -f "${FIFO}" # Make sure to delete a possible old fifo.
mkfifo "${FIFO}" # Create the fifo.


# This function is responsible to spawn the background processes for updating the segments.
# It compose a bunch of values used for each segment, the update process have to be aware about.
# Manage the order of segments and their colors.
#
function initSegments {
  # Get the segment color list length (background is reference)
  local color_list_length=${#SEGMENT_BACKGROUND_LIST[@]}


  # -------- Left Segments Begin ----------

  # Always remember the background from the last segement, cause it is necessary for the separator.
  # The most left segment of the right site has to predecessor, so use the bars default background.
  local next_segment_background

  # Initialize the left segments.
  for (( i=0; i<${#SEGMENT_LIST_LEFT[@]}; i++ )) ; do
    # Get the next segment name.
    local segmentName="${SEGMENT_LIST_LEFT[i]}"

    # Use default segment colors in case no color list is defined.
    if [[ $color_list_length -eq 0 ]] ; then
      current_segment_background=$SEGMENT_BACKGROUND_DEFAULT
      current_segment_foreground=$SEGMENT_FOREGROUND_DEFAULT
      next_segment_background=$SEGMENT_BACKGROUND_DEFAULY

    # Circle trough the color list based on the list index.
    else
      local color_index=$(($i % $color_list_length))

      current_segment_background=${SEGMENT_BACKGROUND_LIST[color_index]}
      current_segment_foreground=${SEGMENT_FOREGROUND_LIST[color_index]}

      local color_index_next=$(($((i +1)) % $color_list_length))
      next_segment_background=${SEGMENT_BACKGROUND_LIST[color_index_next]}

      # Use default color if any color is not specified.
      [[ "$current_segment_background" = '' ]] && current_segment_background=$SEGMENT_BACKGROUND_DEFAULT
      [[ "$current_segment_foreground" = '' ]] && current_segment_foreground=$SEGMENT_FOREGROUND_DEFAULT
      [[ "$next_segment_background" = '' ]] && next_segment_background=$SEGMENT_BACKGROUND_DEFAULT
    fi
   

    # Reset next segment background for last left segment.
    if [[ "$i" = "$((${#SEGMENT_LIST_LEFT[@]}-1))" ]] ; then
      next_segment_background=$DEFAULT_BACKGROUND
    fi


    # Open a background process, which updates this segment.
    updateSegment "${SEGMENT_UPDATE_INTERVAL_DEFAULT}s" "$segmentName" $i "l" "$current_segment_background" "$current_segment_foreground" "" "$next_segment_background" &
  done

  # -------- Left Segments Done ----------


  # ------- Center Segments Begin ----------
  
  local previous_segment_background=$DEFAULT_BACKGROUND
  local next_segment_background

  for (( i=0; i<${#SEGMENT_LIST_CENTER[@]}; i++ )) ; do
    # Get the next segment name.
    local segmentName="${SEGMENT_LIST_CENTER[i]}"
   
    # Use default segment colors in case no color list is defined.
    if [[ $color_list_length -eq 0 ]] ; then
      current_segment_background=$SEGMENT_BACKGROUND_DEFAULT
      current_segment_foreground=$SEGMENT_FOREGROUND_DEFAULT
      next_segment_background=$SEGMENT_BACKGROUND_DEFAULY

    # Circle trough the color list based on the list index from the center segment to the outer ones.
    else
      local middleIndex=$((${#SEGMENT_LIST_CENTER[@]} / 2)) # Is rounded down for odd number of segments.

      # Even number of center segments.
      if [[ $((${#SEGMENT_LIST_CENTER[@]} % 2)) -eq 0 ]] ; then
        # Differ between segments before the "middle" and after, so the both middle segments get the same color and afterwards the color list is iterated.
        [[ $i -lt $middleIndex ]] && local distance=$(($middleIndex - $i - 1))
        [[ $i -ge $middleIndex ]] && local distance=$(($middleIndex - $i))

      # Odd number of center segments.
      else 
        local distance=$(($middleIndex - $i)) # The distance of the segment index to the middle segment.
      fi

      local color_index=${distance##*-} # Convert to a positive number.

      current_segment_background=${SEGMENT_BACKGROUND_LIST[color_index]}
      current_segment_foreground=${SEGMENT_FOREGROUND_LIST[color_index]}

      local color_index_next=$(($((i +1)) % $color_list_length))
      next_segment_background=${SEGMENT_BACKGROUND_LIST[$(($color_index + 1))]}

      # Use default color if any color is not specified.
      [[ "$current_segment_background" = '' ]] && current_segment_background=$SEGMENT_BACKGROUND_DEFAULT
      [[ "$current_segment_foreground" = '' ]] && current_segment_foreground=$SEGMENT_FOREGROUND_DEFAULT
      [[ "$next_segment_background" = '' ]] && next_segment_background=$SEGMENT_BACKGROUND_DEFAULT
    fi
   

    # Reset next segment background for last left segment.
    [[ "$i" = "$((${#SEGMENT_LIST_CENTER[@]} -1))" ]] && next_segment_background=$DEFAULT_BACKGROUND



    # Open a background process, which updates this segment.
    updateSegment "${SEGMENT_UPDATE_INTERVAL_DEFAULT}s" "$segmentName" $i "c" ${current_segment_background} ${current_segment_foreground} ${previous_segment_background} ${next_segment_background} &

    # Update previous segment background.
    previous_segment_background=$current_segment_background
  done

  # ------- Center Segments Done ----------


  # ------- Right Segments Begin ----------

  # The most left right segment has no left segment, so it use the default background color for the separator.
  previous_segment_background=$DEFAULT_BACKGROUND

  for (( i=0; i<${#SEGMENT_LIST_RIGHT[@]}; i++ )) ; do
    # Get the next segment name.
    local segmentName="${SEGMENT_LIST_RIGHT[i]}"

    # Use default segment colors in case no color list is defined.
    if [[ $color_list_length -eq 0 ]] ; then
      current_segment_background=$SEGMENT_BACKGROUND_DEFAULT
      current_segment_foreground=$SEGMENT_FOREGROUND_DEFAULT

    # Circle trough the color list based on the list index.
    else
      # Use reverse order of the list to have symmetry with the left elements.
      local color_index=$(($color_list_length - $(($i % $color_list_length)) -1))

      current_segment_background=${SEGMENT_BACKGROUND_LIST[color_index]}
      current_segment_foreground=${SEGMENT_FOREGROUND_LIST[color_index]}

      # Use default color if any color is not specified.
      [[ "$current_segment_background" = '' ]] && current_segment_background=$SEGMENT_BACKGROUND_DEFAULT
      [[ "$current_segment_foreground" = '' ]] && current_segment_foreground=$SEGMENT_FOREGROUND_DEFAULT
    fi


    # Open a background process, which updates this segment.
    updateSegment "${SEGMENT_UPDATE_INTERVAL_DEFAULT}s" "$segmentName" $i "r" "$current_segment_background" "$current_segment_foreground" "$previous_segment_background" "" &

    # Update previous segment background.
    previous_segment_background=$current_segment_background
  done

  # ------- Right Segments Done ----------

}


# Background process that call the segments function to get the current state.
# Based on the given arguments this function design the format string for the bar.
# This function is aware of the position of the segment.
# The updated format string will be written to the fifo, where it gets read and pass to the bar.
#
# Arguments:
#   $1 - The interval in which the segment should be updated
#   $2 - Name of the segment (used as reference)
#   $3 - Index in the sement order
#   $4 - Orientiation [l|r|c]
#   $5 - Background color of this segment
#   $6 - Foreground color of this segment
#   $7 - Background color of the previous segment (for the separator)
#   $8 - Background color of the next segment (for the separator)
#

function updateSegment {
  # Define persistent properties.
  
  # Center segments are devided into left, center and right segments, which defines the separtor.
  # In case of two middle segment by a even number of center segments, between both are no separator. 
  local centerMiddleIndex=$((${#SEGMENT_LIST_CENTER[@]} / 2)) # Is rounded down for odd number of segments.
  local centerDistance=$(($centerMiddleIndex - $i)) # The distance of the segment index to the middle segment.


  # Left separator.
  local left_separator_format_string=""

  # For center segments.
  if [[ "$4" = 'c' ]] ; then
    # The left center segments
    if [[ ${centerDistance} -ge 0 ]] ; then
      # In case it is the most left center segment
      if [[ ${3} -eq 0 ]] ; then
        left_separator_format_string="%{B${7} F${5}}${SEGMENT_SEPARATOR_CENTER_OUTER_LEFT}"

      else 
        left_separator_format_string="%{B${7} F${5}}${SEGMENT_SEPARATOR_CENTER_INNER_LEFT}"
      fi
    fi

  # For right segments.
  elif [[ "$4" = 'r' ]] ; then
    # In case it is the most left right segment.
    if [[ ${3} -eq 0 ]] ; then
      left_separator_format_string="%{B${7} F${5}}${SEGMENT_SEPARATOR_RIGHT_OUTER}"

    # For all right segments after.
    else 
      left_separator_format_string="%{B${7} F${5}}${SEGMENT_SEPARATOR_RIGHT_INNER}"
    fi
  fi
  
  # -----


  # Right separator
  local right_separator_format_string=""

  if [[ "$4" = 'l' ]] ; then
    # In case it is the most right left segment.
    if [[ ${3} -eq $((${#SEGMENT_LIST_LEFT[@]} - 1)) ]] ; then
      right_separator_format_string="%{B${8} F${5}}${SEGMENT_SEPARATOR_LEFT_OUTER}"

    # For all left segments before.
    else
      right_separator_format_string="%{B${8} F${5}}${SEGMENT_SEPARATOR_LEFT_INNER}"
    fi

  elif [[ "$4" = 'c' ]] ; then
    # The right center segments
    if [[ ${centerDistance} -le 0 ]] ; then
      # In case it is the most right center segment
      if [[ ${3} -eq $((${#SEGMENT_LIST_CENTER[@]} - 1)) ]] ; then
        right_separator_format_string="%{B${8} F${5}}${SEGMENT_SEPARATOR_CENTER_OUTER_RIGHT}"

      else 
        right_separator_format_string="%{B${8} F${5}}${SEGMENT_SEPARATOR_CENTER_INNER_RIGHT}"
      fi
    fi
  fi


  local state_color_before="%{B${5} F${6}}"
  local color_clear="%{F- B-}"
  local segment_format_string=

  # Store the state to be aware of changes in the state.
  local lastState=""

  # Start a endless loop for this process, responsible for this segment.
  while true ; do
    # Get the current state of the segment, by its reposible function.
    local state=$("getState_$2")

    # Do nothing further, it the state has not changed.
    if [[ ! "$lastState" = "$state" ]] ; then
      # Store state for next update.
      lastState="$state"

      # Compose the segment format string.
      segment_format_string="${left_separator_format_string}${state_color_before} ${state} ${right_separator_format_string}${color_clear}"

      # Pass the format string to the fifo. 
      printf "%s\n" "${4}${3}${segment_format_string}" > "${FIFO}" &
    fi

    # Wait for the defined period.
    sleep "$1"
  done
}

# Function which run in background and read from the fifo.
# Hold an array where each entry is the format string of one segment.
# An fifo entry is suffixed by the segment index, which is equal to the array index.
# Pass the concatenation of all segments format strings to the standard output.
#
function reading {
  # Arrays which holds the current format string for each orientation segments.
  declare -A format_string_list_left=()
  declare -A format_string_list_left=()
  declare -A format_string_list_right=()

  # Define local variables.
  local orientation # Decide in which list the segment belong to.
  local index # Temporally store the index of the to update segement.
  local format_string_left # Hold the concatenation of all left segments.
  local format_string_center # Hold the concatenation of all center segments.
  local format_string_right # Hold the concatenation of all right segments.
  local format_string # Hold the concatenation of all format strings.

  # Keep open endless loop as long as the process is running.
  while true ; do
    # Wait until fifo has content.
    if read line ; then
      # Parse the first and second character as the orientation and the index of the segment.
      orientation=${line:0:1}
      index=${line:1:1}

      # Update the format string in the reponsive list.
      [[ "$orientation" = 'l' ]] && format_string_list_left[$index]="${line:2}"
      [[ "$orientation" = 'c' ]] && format_string_list_center[$index]="${line:2}"
      [[ "$orientation" = 'r' ]] && format_string_list_right[$index]="${line:2}"

      # Pass the current format string list to the bar.
      format_string_left=$(printf %s "${format_string_list_left[@]}" $'\n')
      format_string_center=$(printf %s "${format_string_list_center[@]}" $'\n')
      format_string_right=$(printf %s "${format_string_list_right[@]}" $'\n')
        format_string="%{l}${format_string_left}%{c}${format_string_center}%{r}${format_string_right}"
      echo ${format_string}
    fi

    # Sleep minimum of time, after which a new update is possible.
    # In case that the fifo directly contains a new update, it would be ignored by the lemonbar, if no short delay is inserted.
    sleep 0.03s
  done < "$FIFO"
}


# Getting started
initSegments # Start all background processes, handling the segments.
reading | # Run process which read from the fifo and pass the whole format string to the bar.
$(dirname $0)/lemonbar -p -d "$BAR_BOTTOM_ARG" -f "$FONT_DEFAULT:size=$FONT_SIZE" -B "$DEFAULT_BACKGROUND" -F "$DEFAULT_FOREGROUND" -g "x$HEIGHT" & # Run lemonbar in background and read from the standard input.
wait # Wait here and do not end. 
