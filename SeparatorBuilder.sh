#!/bin/bash

# Utility script to construct a format string with a segment separator.
# Segment separators are differed between left and right ones.
# A segment separator has to be aware of the background color of the next or previous segment (depends on the orientation).
#
# This functionality has been sourced out, to save permanent memory storage in return of temporally.
#
# Arguments:
#   $1 - orientation of separator (left or right of the segment) [l|r]
#   $2 - orientation of the segment (in the bar) [l|c|r]
#   $3 - Index of the segment in its section
#   $4 - Background color of the segment itself
#   $5 - Background color of the previous segment
#   $6 - Background color of the next segment
#

# Store the source and configuration directory, cause it is used several times.
BASE_DIR="$(dirname $0)"
CONFIG_DIR=$BASE_DIR/config

# Load the default and user configurations.
source $CONFIG_DIR/default.conf # Default values for all necessary variables.
source $CONFIG_DIR/custom.conf # Load after default values to be able to overwrite them.


# Build the format string for a left separator of a segment.
# The separator depends on the orientation of the segment and
# if it is an inner segment or the most outer one.
# Not each segment has a left separator!
#
# Arguments:
#   $1 - Orientation of the segment [l|r|c] (left gets ignored here)
#   $2 - Index of the segment in its section (to specify inner and most outer)
#   $3 - Background color of this segment
#   $4 - Background color of the previous segment
#
function getLeftSeparator {
  # For center segments.
  if [[ "$1" = 'c' ]] ; then
    # Left center segments
    if [[ ${centerDistance} -ge 0 ]] ; then
      # In case it is the most left center segment
      if [[ ${2} -eq 0 ]] ; then
        echo "%{B${4} F${3} T2}${SEGMENT_SEPARATOR_CENTER_OUTER_LEFT}%{B- F- T1}"
        return

      # For all left center segments after.
      else 
        echo "%{B${4} F${3} T2}${SEGMENT_SEPARATOR_CENTER_INNER_LEFT}%{B- F- T1}"
        return
      fi

    # Right center segments don't have a left separator.
    fi

  # For right segments.
  elif [[ "$1" = 'r' ]] ; then
    # In case it is the most left right segment.
    if [[ ${2} -eq 0 ]] ; then
      echo "%{B${4} F${3} T2}${SEGMENT_SEPARATOR_RIGHT_OUTER}%{B- F- T1}"
      return

    # For all right segments after.
    else 
      echo "%{B${4} F${3} T2}${SEGMENT_SEPARATOR_RIGHT_INNER}%{B- F- T1}"
      return
    fi
  fi

  # Left segments don't have a left separator.
}


# Build the format string for a right separator of a segment.
# The separator depends on the orientation of the segment and
# if it is an inner segment or the most outer one.
# Not each segment has a left separator!
#
# Arguments:
#   $1 - Orientation of the segment [l|r|c] (left gets ignored here)
#   $2 - Index of the segment in its section (to specify inner and most outer)
#   $3 - Background color of this segment
#   $4 - Background color of the next segment
#
function getRightSeparator {
  # For left segments.
  if [[ "$1" = 'l' ]] ; then
    # In case it is the most right left segment.
    if [[ ${2} -eq $((${#SEGMENT_LIST_LEFT[@]} - 1)) ]] ; then
      echo "%{B${4} F${3} T2}${SEGMENT_SEPARATOR_LEFT_OUTER}%{B- F- T1}"

    # For all left segments before.
    else
      echo "%{B${4} F${3} T2}${SEGMENT_SEPARATOR_LEFT_INNER}%{B- F- T1}"
    fi

  # For center segments.
  elif [[ "$1" = 'c' ]] ; then
    # Right center segments.
    if [[ ${centerDistance} -le 0 ]] ; then
      # In case it is the most right center segment
      if [[ ${2} -eq $((${#SEGMENT_LIST_CENTER[@]} - 1)) ]] ; then
        echo "%{B${4} F${3} T2}${SEGMENT_SEPARATOR_CENTER_OUTER_RIGHT}%{B- F- T1}"

      # For all right center segments before.
      else 
        echo "%{B${4} F${3} T2}${SEGMENT_SEPARATOR_CENTER_INNER_RIGHT}%{B- F- T1}"
      fi
    fi

    # Left center segments don't have a right separator.
  fi

  # Right segments don't have a right separator.
}



# Getting started.
# Center segment need some pre-calculations.
if [[ "$2" = 'c' ]] ; then
  # Center segments are divided into left, center and right segments, which defines the separator.
  # In case of two middle segments (by a even number of center segments), between both are no separator. 
  centerMiddleIndex=$((${#SEGMENT_LIST_CENTER[@]} / 2)) # Is rounded down for odd number of segments.
  centerDistance=$(($centerMiddleIndex - $3)) # The distance of the segment index to the middle segment.
fi


# Differ between the request of a left or right separator by the first argument.
# TODO: Maybe left and right must switch the last arguments as color.
if [[ "$1" = 'l' ]] ; then
  echo $(getLeftSeparator $2 $3 $4 $5)
  
elif [[ "$1" = 'r' ]] ; then
  echo $(getRightSeparator $2 $3 $4 $6)
fi
