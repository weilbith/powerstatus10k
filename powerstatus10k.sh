#!/bin/bash
# shellcheck disable=SC1090 

# Name used for paths specific for this application.
NAME="powerstatus10k"

# Declare and assign information for all (sub-)components.

# Make sure the XDG environment variables are defined.
[[ -z "$XDG_CONFIG_HOME" ]] && XDG_CONFIG_HOME="$HOME/.config"
[[ -z "$XDG_CACHE_HOME" ]] && XDG_CACHE_HOME="$HOME/.cache"
[[ -z "$XDG_RUNTIME_DIR" ]] && XDG_RUNTIME_DIR="/tmp"

# Paths
export POWERSTATUS10K_DIR_RUNTIME
export POWERSTATUS10K_DIR_FIFOS
export POWERSTATUS10K_DIR_CONFIG_USER
export POWERSTATUS10K_DIR_CONFIG_GLOBAL
export POWERSTATUS10K_DIR_COMPONENTS
export POWERSTATUS10K_DIR_SEGMENTS_GLOBAL
export POWERSTATUS10K_DIR_SEGMENTS_USER

POWERSTATUS10K_DIR_CONFIG_GLOBAL="/etc/$NAME"
POWERSTATUS10K_DIR_CONFIG_USER="$XDG_CONFIG_HOME/$NAME"
POWERSTATUS10K_DIR_RUNTIME="$XDG_RUNTIME_DIR/$NAME"
POWERSTATUS10K_DIR_FIFOS="$POWERSTATUS10K_DIR_RUNTIME/fifos"
POWERSTATUS10K_DIR_COMPONENTS="/usr/lib/$NAME/components"
POWERSTATUS10K_DIR_SEGMENTS_GLOBAL="/usr/share/$NAME/segments"
POWERSTATUS10K_DIR_SEGMENTS_USER="$XDG_CACHE_HOME/$NAME/segments"


# Files
export POWERSTATUS10K_FILE_CONFIG_GLOBAL
export POWERSTATUS10K_FILE_CONFIG_USER
export POWERSTATUS10K_FILE_FIFO_MAIN

POWERSTATUS10K_FILE_CONFIG_GLOBAL="$POWERSTATUS10K_DIR_CONFIG_GLOBAL/powerstatus10k.conf"
POWERSTATUS10K_FILE_CONFIG_USER="$POWERSTATUS10K_DIR_CONFIG_USER/powerstatus10k.conf"
POWERSTATUS10K_FILE_FIFO_MAIN="$POWERSTATUS10K_DIR_FIFOS/main"


# Component names
export POWERSTATUS10K_COMPONENT_UTILS_COLOR
export POWERSTATUS10K_COMPONENT_UTILS_ABBREVIATION
export POWERSTATUS10K_COMPONENT_SEGMENT_FINDER
export POWERSTATUS10K_COMPONENT_SEGMENT_HANDLER
export POWERSTATUS10K_COMPONENT_SEPARATOR_BUILDER

POWERSTATUS10K_COMPONENT_UTILS_COLOR="$POWERSTATUS10K_DIR_COMPONENTS/ColorUtils.sh"
POWERSTATUS10K_COMPONENT_UTILS_ABBREVIATION="$POWERSTATUS10K_DIR_COMPONENTS/AbbreviationUtils.sh"
POWERSTATUS10K_COMPONENT_SEGMENT_FINDER="$POWERSTATUS10K_DIR_COMPONENTS/SegmentFinder.sh"
POWERSTATUS10K_COMPONENT_SEGMENT_HANDLER="$POWERSTATUS10K_DIR_COMPONENTS/SegmentHandler.sh"
POWERSTATUS10K_COMPONENT_SEPARATOR_BUILDER="$POWERSTATUS10K_DIR_COMPONENTS/SeparatorBuilder.sh"

# Create essential directories to make sure no component stuck on that.
mkdir -p "$POWERSTATUS10K_DIR_FIFOS"

# ---


# Load configurations
# Load the default and user configurations.
source "$POWERSTATUS10K_FILE_CONFIG_GLOBAL" # Default values for all necessary variables.
[[ -f "$POWERSTATUS10K_FILE_CONFIG_USER" ]] && \
  source "$POWERSTATUS10K_FILE_CONFIG_USER" # Load after default values to be able to overwrite them (only if exist).

# Source exported functionality.
source "$POWERSTATUS10K_COMPONENT_UTILS_COLOR" # Utility functions for colors.
source "$POWERSTATUS10K_COMPONENT_SEGMENT_FINDER" # Dynamically load segments which are used.

# Define deviated variables.
[[ "$BOTTOM" = true ]] && BAR_BOTTOM_ARG="-b"
[[ "$FORCE_DOCKING" = true ]] && BAR_FORCE_DOCKING="-d"

# ---


# Close procedure setup
# List of all process identifiers of the subscripts which handle the segments.
PID_LIST=""

# Execute cleanup function at script exit.
trap cleanup EXIT

# ---


# Prepare the main FIFO.
rm -f "$POWERSTATUS10K_FILE_FIFO_MAIN" # Make sure to delete a possible old FIFO.
mkfifo "$POWERSTATUS10K_FILE_FIFO_MAIN" # Create the FIFO.

# ---


# Functions

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
  local segment_list
  eval "segment_list=(\"\${SEGMENT_LIST_${orientation}[@]}\")"


  # Iterate over all segments in this section.
  for (( i=0; i<${#segment_list[@]}; i++ )) ; do
    # Get the next segment name.
    local segment_name
    segment_name="${segment_list[i]}"

    # Get the implementation and configuration information for this segment.
    local implementationInfo
    local configurationInfo

    implementationInfo=$(getSegmentImplementation "$segment_name")
    configurationInfo=$(getSegmentConfiguration "$segment_name")

    # Exit if no implementation could been found.
    if [[ -z "$implementationInfo" ]] ; then
      echo "Could not load segment: $segment_name"
      exit 1
    fi

    # Split the information into their parameters.
    IFS=':' read -ra implementationParam <<< "$implementationInfo"
    IFS=':' read -ra configurationParam <<< "$configurationInfo"
    segment_name=${implementationParam[0]}
    implementation=${implementationParam[1]}
    configuration=${configurationParam[1]}

    # Get the back- and foreground colors for this segments.
    local current_segment_background
    local current_segment_foreground
    local previous_segment_background
    local next_segment_background
    
    current_segment_background=$(getSegmentBackground "$1" $i)
    current_segment_foreground=$(getSegmentForeground "$1" $i)
    previous_segment_background=$(getSegmentBackground "$1" $((i - 1)))
    next_segment_background=$(getSegmentBackground "$1" $((i + 1)))

    # Open a background process, which updates this segment.
    "$POWERSTATUS10K_COMPONENT_SEGMENT_HANDLER" \
      "$segment_name" "$1" $i \
      "$current_segment_background" "$current_segment_foreground" "$previous_segment_background" "$next_segment_background" \
      "$implementation" "$configuration" \
      &

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
  #${#SEGMENT_LIST_LEFT[@]}
  # Arrays which holds the current format string for each orientation segments.
  declare -a format_string_list_left=( $(for (( i=1; i<=${#SEGMENT_LIST_LEFT[@]}; i++ )); do echo ""; done ) )
  declare -a format_string_list_center=( $(for (( i=1; i<=${#SEGMENT_LIST_CENTER[@]}; i++ )); do echo ""; done ) )
  declare -a format_string_list_right=( $(for (( i=1; i<=${#SEGMENT_LIST_RIGHT[@]}; i++ )); do echo ""; done ) )

  # Define local variables.
  local orientation # Decide in which list the segment belong to.
  local index # Temporally store the index of the to update segment.
  local format_string_left # Hold the concatenation of all left segments.
  local format_string_center # Hold the concatenation of all center segments.
  local format_string_right # Hold the concatenation of all right segments.
  local format_string # Hold the concatenation of all format strings.

  # Keep open endless loop as long as the process is running.
  while true ; do
    # Wait until FIFO has content.
    # Be aware that this does read the whole FIFO and does not to be split.
    state="$(cat "$POWERSTATUS10K_FILE_FIFO_MAIN")"
    readarray -t lines <<<"$state"

    # Parse each entry of the read FIFO content.
    for (( i=0; i<${#lines[@]}; i++ )) ; do
      line="${lines[i]}"

      # Parse the first and second character as the orientation and the index of the segment.
      index=$((${line:0:1} + 1)) # Input counts from zero, but associative array from one.
      orientation=${line:1:1}

      # Update the format string in the responsive list.
      [[ "$orientation" = 'l' ]] && format_string_list_left[$index]="${line:2}"
      [[ "$orientation" = 'c' ]] && format_string_list_center[$index]="${line:2}"
      [[ "$orientation" = 'r' ]] && format_string_list_right[$index]="${line:2}"

      # Pass the current format string list to the bar.
      format_string_left=$(printf %s "${format_string_list_left[@]}" $'\n')
      format_string_center=$(printf %s "${format_string_list_center[@]}" $'\n')
      format_string_right=$(printf %s "${format_string_list_right[@]}" $'\n')
      format_string="%{l}${format_string_left}%{c}${format_string_center}%{r}${format_string_right}"

      # Forward this to the bar.
      echo "${format_string}"

      # Sleep minimum of time, after which a new update is possible.
      # In case that the FIFO directly contains a new update, it would be ignored by the lemonbar,
      # if no short delay is inserted
      sleep 0.03s
    done

  done
}


# Getting started
initSegments # Start all background processes, handling the segments.
reading |  # Run process which read from the fifo and pass the whole format string to the bar.
lemonbar \
  -p "$BAR_FORCE_DOCKING" "$BAR_BOTTOM_ARG" -g "x$HEIGHT" \
  -f "$FONT_DEFAULT:size=$FONT_SIZE_DEFAULT" -f "$FONT_SEPARATORS:size=$FONT_SIZE_SEPARATORS" \
  -B "$DEFAULT_BACKGROUND" -F "$DEFAULT_FOREGROUND" \
  "$OPTIONAL_BAR_ARGUMENTS" \
  & # Start lemonbar in background and read from the standard input.

PID_LIST="$PID_LIST $!" # Add the lemonbar process identifier to the list as well.
wait # Wait here and do not end. 
