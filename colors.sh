#!/bin/bash

# Get the background color of a segment, sepcified by its orientation and index.
# Indexes out of range of the respective segment list, are return the bars default color.
#
# Arguments:
#    $1 - orientation [l|c|r]
#    $2 - index (in the respective orientation field)
#
function getSegmentBackground () {
  # Get the number of segements for the respective segment list.
  [[ "$1" = 'l' ]] && local segment_length=$((${#SEGMENT_LIST_LEFT[@]} -1))
  [[ "$1" = 'c' ]] && local segment_length=$((${#SEGMENT_LIST_CENTER[@]} -1))
  [[ "$1" = 'r' ]] && local segment_length=$((${#SEGMENT_LIST_RIGHT[@]} -1))

  # Return the default bar background for segment indexes outsite of the list.
  if [[ $2 -lt 0 || $2 -gt $segment_length ]] ; then
    echo $DEFAULT_BACKGROUND
  
  else 
    echo $(getSegmentColor $1 $2 'bg')
  fi
}


# Get the foreground color of a segment, specified by its orientiation and index.
# Do not check for an valid index here. In such case a "random" color gets returned.
#
# Arguments:
#    $1 - orientation [l|c|r]
#    $2 - index (in the respective orientation field)
#
function getSegmentForeground () {
  echo $(getSegmentColor $1 $2 'fg')
}


# Get the fore- or background color for a segment.
# The segment is specified by its orientation and index.
# 
# Arguments:
#    $1 - orientation [l|c|r]
#    $2 - index (in the respective orientation field)
#    $3 - back- or foreground [bg|fg]
#
function getSegmentColor () {
  [[ "$3" = 'bg' ]] && local type="BACKGROUND" || local type="FOREGROUND"

  color_list_length=${#SEGMENT_BACKGROUND_LIST[@]}

  if [[ ! $color_list_length -eq 0 ]] ; then
    # Get the color index.
    if [[ "$1" = 'l' ]] ; then
      # Circle trough the list based on its length.
      local color_index=$(($2 % $color_list_length))

    elif [[ "$1" = 'c' ]] ; then
      # Even number of center segments.
      if [[ $((${#SEGMENT_LIST_CENTER[@]} % 2)) -eq 0 ]] ; then
        # Differ between segments before the "middle" and after, so the both middle segments get the same color and afterwards the color list is iterated.
        [[ $2 -lt $middleIndex ]] && local distance=$(($middleIndex - $2 - 1))
        [[ $2 -ge $middleIndex ]] && local distance=$(($middleIndex - $2))

      # Odd number of center segments.
      else 
        local distance=$(($middleIndex - $2)) # The distance of the segment index to the middle segment.
      fi

      local color_index=${distance##*-} # Convert to a positive number.

    else
      # Use the color list in reverse order to have a symmetry.
      local color_index=$(($color_list_length - $(($2 % $color_list_length)) - 1))
    fi

    # Return the correct color from the color list.
    eval "local color=\${SEGMENT_${type}_LIST[\$color_index]}"

    # Use default color if the retrieved one is not defined or empty.
    [[ "$color"  = '' ]] && eval "local color=\$SEGMENT_${type}_DEFAULT"

    # Return the color.
    echo "$color"


  else
    # Simply return the default color.
    echo $(eval echo "\$SEGMENT_${type}_DEFAULT")
  fi
}
