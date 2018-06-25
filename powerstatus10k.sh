#!/bin/bash

# Store the source and configuration directory, cause it is used several times.
BASE_DIR="$(dirname $0)"
CONFIG_DIR=$BASE_DIR/config

# Load the default and user configurations.
source $CONFIG_DIR/default.conf # Default values for all necessary variables.
source $CONFIG_DIR/custom.conf # Load after default values to be able to overwrite them.

# Source exported functionality.
source $BASE_DIR/ColorUtils.sh # Utility functions for colors.
source $BASE_DIR/SegmentFinder.sh # Dynamically load segments which are used.

# Script "Imports" 
SCRIPT_SEGMENT_HANDLER=$BASE_DIR/SegmentHandler.sh

# List of all PIDs of the subscripts which handle the segments.
PID_LIST=""

# Define deviated variables.
[[ "$BOTTOM" = true ]] && BAR_BOTTOM_ARG="-b"

# Execute cleanup function at script exit.
trap cleanup EXIT


# Prepare the fifo.
rm -f "${FIFO}" # Make sure to delete a possible old fifo.
mkfifo "${FIFO}" # Create the fifo.


# Cleanup the script when it gets exited.
# This will kill all started child processes.
#
function cleanup {
  # Iterate over all process identifiers to kill them.
  for pid in $PID_LIST ; do
    kill $pid
  done
}


# Caller function to initialize all segment sections.
#
function initSegments {
  initSegmentSection 'l'
  initSegmentSection 'c'
  initSegmentSection 'r'
}


# Initialize all segments for a specific section.
# By this it spawns a background process per segment which will update its content.
# Therefore it compose a bunch of values this process has to be aware of.
#
# Arguments:
#   $1 - orientation [l|c|r]
#
function initSegmentSection {
  # Expand the orientation to the variable substring definition.
  [[ "$1" = 'l' ]] && local orientation="LEFT"
  [[ "$1" = 'c' ]] && local orientation="CENTER"
  [[ "$1" = 'r' ]] && local orientation="RIGHT"

  # Get the segment list for this section by the orientation.
  eval "local segment_list=(\"\${SEGMENT_LIST_${orientation}[@]}\")"

  # Iterate over all segments in this section.
  for (( i=0; i<${#segment_list[@]}; i++ )) ; do
    # Get the next segment name.
    local segment_name="${segment_list[i]}"

    # Load the implementation and configuration of the segment.
    local implementation=$(getSegmentImplementation "$segment_name")
    local configuration=$(getSegmentConfiguration "$segment_name")

    # Exit if no implementation could been found.
    if [[ -z "$implementation" ]] ; then
      echo "Could not load segment: $segment_name"
      exit 1
    fi

    # Get the back- and foreground colors for this segments.
    local current_segment_background=$(getSegmentBackground $1 $i)
    local current_segment_foreground=$(getSegmentForeground $1 $i)
    local previous_segment_background=$(getSegmentBackground $1 $(($i - 1)))
    local next_segment_background=$(getSegmentBackground $1 $(($i + 1)))

    # Define the update interval by try to get a custom defined one or use defaul.
    local update_interval
    eval "local custom_update_interval=\$${segment_name^^}_UPDATE_INTERVAL"

    if [[ ${custom_update_interval} -gt 0 ]] ; then
      # Use custom interval.
      update_interval=$custom_update_interval
    else
      # Use default inverval.
      update_interval=${DEFAULT_UPDATE_INTERVAL}
    fi

    # Open a background process, which updates this segment.
    $SCRIPT_SEGMENT_HANDLER "${update_interval}s" "$segment_name" $1 $i "$current_segment_background" "$current_segment_foreground" "$previous_segment_background" "$next_segment_background" $implementation $configuration &

    # Store the PID to be able to kill it later on.
    PID_LIST="$PID_LIST $!"
  done
}


# Function which run in background and read from the FIFO.
# Hold an array where each entry is the format string of one segment.
# An FIFO entry is suffixed by the segment index, which is equal to the array index.
# Pass the concatenation of all segments format strings to the standard output.
#
function reading {
  # Arrays which holds the current format string for each orientation segments.
  declare -A format_string_list_left=()
  declare -A format_string_list_left=()
  declare -A format_string_list_right=()

  # Define local variables.
  local orientation # Decide in which list the segment belong to.
  local index # Temporally store the index of the to update segment.
  local format_string_left # Hold the concatenation of all left segments.
  local format_string_center # Hold the concatenation of all center segments.
  local format_string_right # Hold the concatenation of all right segments.
  local format_string # Hold the concatenation of all format strings.

  # Keep open endless loop as long as the process is running.
  while true ; do
    # Wait until fifo has content.
    if read line ; then
      # Parse the first and second character as the orientation and the index of the segment.
      index=${line:0:1}
      orientation=${line:1:1}

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
    # In case that the FIFO directly contains a new update, it would be ignored by the lemonbar, if no short delay is inserted.
    sleep 0.03s
  done < "$FIFO"
}


# Getting started
initSegments # Start all background processes, handling the segments.
reading | # Run process which read from the fifo and pass the whole format string to the bar.
$BASE_DIR/lemonbar -p -d "$BAR_BOTTOM_ARG" -f "$FONT_DEFAULT:size=$FONT_SIZE_DEFAULT" -f "$FONT_SEPARATORS:size=$FONT_SIZE_SEPARATORS" -B "$DEFAULT_BACKGROUND" -F "$DEFAULT_FOREGROUND" -g "x$HEIGHT" & # Run lemonbar in background and read from the standard input.
wait # Wait here and do not end. 
