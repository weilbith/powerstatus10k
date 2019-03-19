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
export POWERSTATUS10K_FILE_PID

POWERSTATUS10K_FILE_CONFIG_GLOBAL="$POWERSTATUS10K_DIR_CONFIG_GLOBAL/$NAME.conf"
POWERSTATUS10K_FILE_CONFIG_USER="$POWERSTATUS10K_DIR_CONFIG_USER/$NAME.conf"
POWERSTATUS10K_FILE_FIFO_MAIN="$POWERSTATUS10K_DIR_FIFOS/main"
POWERSTATUS10K_FILE_PID="$POWERSTATUS10K_DIR_RUNTIME/pid"


# Component names
export POWERSTATUS10K_COMPONENT_READER
export POWERSTATUS10K_COMPONENT_UTILS_COLOR
export POWERSTATUS10K_COMPONENT_UTILS_ABBREVIATION
export POWERSTATUS10K_COMPONENT_SEGMENT_FINDER
export POWERSTATUS10K_COMPONENT_SEGMENT_HANDLER
export POWERSTATUS10K_COMPONENT_SEPARATOR_BUILDER

POWERSTATUS10K_COMPONENT_READER="$POWERSTATUS10K_DIR_COMPONENTS/Reader.sh"
POWERSTATUS10K_COMPONENT_UTILS_COLOR="$POWERSTATUS10K_DIR_COMPONENTS/ColorUtils.sh"
POWERSTATUS10K_COMPONENT_UTILS_ABBREVIATION="$POWERSTATUS10K_DIR_COMPONENTS/AbbreviationUtils.sh"
POWERSTATUS10K_COMPONENT_SEGMENT_FINDER="$POWERSTATUS10K_DIR_COMPONENTS/SegmentFinder.sh"
POWERSTATUS10K_COMPONENT_SEGMENT_HANDLER="$POWERSTATUS10K_DIR_COMPONENTS/SegmentHandler.sh"
POWERSTATUS10K_COMPONENT_SEPARATOR_BUILDER="$POWERSTATUS10K_DIR_COMPONENTS/SeparatorBuilder.sh"

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


# Execute cleanup function at script exit.
trap cleanup EXIT


# ---


# Functions

# Cleanup the script when it gets exited.
# This will kill the whole subtree of processes.
# Since some sub-processes are blocking and will not terminate by killing just
# the group, this must be done manually through the tree.
#
function cleanup {
  own_pid=$$
  group_pid="$(ps -o sid= -p "$own_pid")"
  pid_tree_list="$(ps --no-header --forest -o pid -g "${group_pid// /}")"

  rm -f "$POWERSTATUS10K_FILE_PID"

  while IFS=$'\n' read -r pid || [ -n "$line" ]; do
    [[ "$pid" == "$own_pid" ]] && continue
    kill "${pid// /}" &> /dev/null  # We don't care about the order so some could fail.
  done <<< "$pid_tree_list"
}


# Checks if an instance is already running and terminating it if so.
# Wait until being sure the old instance is not active anymore.
#
function terminate_old_instance {
  [[ ! -f "$POWERSTATUS10K_FILE_PID" ]] && return

  pid="$(cat "$POWERSTATUS10K_FILE_PID")"
  kill "$pid" &> /dev/null

  # Wait until process has finally terminated.
  # This is necessary to make sure to not access the same resources.
  echo -n "Wait until last instance has been terminated."

  while [[ -n "$(ps --no-header "$pid")" ]]; do
    printf '.'
    sleep 0.5
  done
  
  printf ' done\n'
}


# Initial setup to secure a successful run.
# Making sure all necessary directories where to place date are available.
# Also possibly old instances are cleared.
#
function setup {
  # Remove possibly running instance.
  terminate_old_instance
  echo $$ > "$POWERSTATUS10K_FILE_PID"

  # Create essential directories to make sure no component stuck on that.
  mkdir -p "$POWERSTATUS10K_DIR_FIFOS"
  mkdir -p "$POWERSTATUS10K_DIR_RUNTIME"

  # Prepare the main FIFO.
  rm -f "$POWERSTATUS10K_FILE_FIFO_MAIN" # Make sure to delete a possible old FIFO.
  mkfifo "$POWERSTATUS10K_FILE_FIFO_MAIN" # Create the FIFO.
}


# Caller function to initialize all segment sections.
#
function initSegments {
  initSegmentSection 'l'
  initSegmentSection 'c'
  initSegmentSection 'r'
}


# Initialize all segments for a specific section.
# A section consists of a list of segments which have the same orientation.
# It spawns a background process per segment which will update its content.
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
  done
}


# Getting started
setup
initSegments

$POWERSTATUS10K_COMPONENT_READER \
  ${#SEGMENT_LIST_LEFT[@]} \
  ${#SEGMENT_LIST_CENTER[@]} \
  ${#SEGMENT_LIST_RIGHT[@]} \
  | \
lemonbar \
  -p "$BAR_FORCE_DOCKING" \
  "$BAR_BOTTOM_ARG" \
  -g "x$HEIGHT" \
  -f "$FONT_DEFAULT:size=$FONT_SIZE_DEFAULT" \
  -f "$FONT_SEPARATORS:size=$FONT_SIZE_SEPARATORS" \
  -B "$DEFAULT_BACKGROUND" \
  -F "$DEFAULT_FOREGROUND" \
  "$OPTIONAL_BAR_ARGUMENTS" \
  &

wait
