#!/bin/bash

# Define the base folders, where segment implementations are placed in.
SEGMENT_FOLDER_DEFAULT="$(dirname $0)/segments/default"
SEGMENT_FOLDER_CUSTOM="$(dirname $0)/segments/custom"

# Constants
IMPLEMENTATION="implementation"
CONFIGURATION="configuration"


# Get the implementation of a segment.
#
# Arguments:
#   $1 - name of the segment
#
# Return:
#   file path for the segment implementation.
#   (empty if none could been found)
#
function getSegmentImplementation {
  echo $(getSegmentPart $1 $IMPLEMENTATION)
}

# Get the configuration of a segment.
#
# Arguments:
#   $1 - name of the segment
#
# Return:
#   file path for the segments configuration.
#   (empty if none could been found)
#
function getSegmentConfiguration {
  echo $(getSegmentPart $1 $CONFIGURATION)
}

# Search for a part of a segment, defined by its name.
# Use the folders for the default and custom segments to search in.
# Which parts is searched for must defined also.
#
# Arguments:
#   $1 - name of the segment
#   $2 - type of part (implementation|configuration)
#
# Return:
#   file path for the segment part
#   (empty if none could been found)
#
function getSegmentPart {
  # Search at the default segment folder.
  for file in $SEGMENT_FOLDER_DEFAULT/* ; do
    local found=$(checkName $file $1 $2)

    if [[ "$found" = 'true' ]] ; then
      echo "$file"
      return # Stop searching.
    fi
  done

  # Search at the custom segment folder.
  for file in $SEGMENT_FOLDER_CUSTOM/* ; do
    found=$(checkName $file $1 $2)

    if [[ "$found" = 'true' ]] ; then
      echo $file
      return # Stop searching.
    fi
  done

  # No implementation could been found.
}


# Check if the given path of a segment file fits with the requested one.
# Differs between the implementation of a segment and its configuration.
# 
# Arguments:
#   $1 - path to implementation
#   $2 - segment name
#   $3 - implementation or configuration (see constants)
#
# Return:
#   true  - if path fits to the segment name
#   false - else
#
function checkName {
  # Extract the pure file name.
  local basename="$(basename "$1")"
  local name="${basename%.*}"
  local extension="${basename#*.}"

  # Compare the file name of the file with the requested segment name.
  if [[ "$name" = "$2" ]] ; then
    # Check the correct file extension for an implementation.
    if [ "$3" == "$IMPLEMENTATION" -a "$extension" == 'sh' ] ; then
      echo true

    # Check the correct file extension for a configuration.
    elif [ "$3" == "$CONFIGURATION" -a "$extension" == 'conf' ] ; then
      echo true

    # Doesn't fit any.
    else
      echo false
    fi

  else 
    echo false
  fi
}
