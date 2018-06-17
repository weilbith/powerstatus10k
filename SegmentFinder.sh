#!/bin/bash

# Define the base folders, where segment implementations are placed in.
SEGMENT_FOLDER_DEFAULT="$(dirname $0)/segments/default"
SEGMENT_FOLDER_CUSTOM="$(dirname $0)/segments/custom"


# Search for the implemenation of a segment, defined by its name.
# Use the folderss for the default and custom segments to search in.
#
# Arguments:
#   $1 - name of the segment
#
# Return:
#   file path for the segment implementation
#   (empty if noone could been found)
#
function loadPlugin {
  # Search at the default segment implementations.
  for file in $SEGMENT_FOLDER_DEFAULT/* ; do
    local found=$(checkName "$file" "$1")

    if [[ "$found" = 'true' ]] ; then
      echo "$file"
      return # Stop searching.
    fi
  done

  # Search at the custom segment implementations.
  for file in $SEGMENT_FOLDER_CUSTOM/* ; do
    found=$(checkName $file $1)

    if [[ "$found" = 'true' ]] ; then
      echo $file
      return # Stop searching.
    fi
  done

  # No implementation could been found.
}


# Check if the given path of a segment implementation fits with the requested one.
# 
# Arguments:
#   $1 - path to implementation
#   $2 - segment name
#
# Return:
#   true  - if path fits to the segment name
#   false - else
#
function checkName {
  # Extract the pure file name.
  local basename="$(basename "$1")"
  local name="${basename%.*}"

  # Compare the file name of the implementation with the requested segment name.
  if [[ "$name" = "$2" ]] ; then
    echo true

  else 
    echo false
  fi
}
