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
  # Get the file extension for the responsible type.
  [[ "$2" == "$IMPLEMENTATION" ]] && extension="sh"
  [[ "$2" == "$CONFIGURATION" ]] && extension="conf"

  # Segment as repository.
  if [[ "$1" = *'/'* ]] ; then
    name=${1##*/} # The folder name and is the same as the file name.
    name_pure=${name##*powerstatus10k_} # Cut of a possible leading prefix.

    # Get the repository if it does not exist yet.
    if [[ ! -d "${SEGMENT_FOLDER_CUSTOM}/${name}" ]] ; then
      url="https://github.com/${1}.git"
      git clone --depth 1 $url $SEGMENT_FOLDER_CUSTOM/${name}
    fi

    # Define the possible files for the requested type.
    file="${SEGMENT_FOLDER_CUSTOM}/${name}/${name}.${extension}"
    file_pure="${SEGMENT_FOLDER_CUSTOM}/${name}/${name_pure}.${extension}"

    # Check if the file exist to return it.
    # Else the response will leave empty.
    [[ -f "$file" ]] && echo "${name}:${file}" && return
    [[ -f "$file_pure" ]] && echo "${name_pure}:${file_pure}" && return

  # Segment as pure file or sub-directory.
  else
    # Pure file in the default segment folder.
    file="${SEGMENT_FOLDER_DEFAULT}/${1}.${extension}"
    [[ -f "$file" ]] && echo "${1}:${file}" && return

    # Segment in a sub-directory of the default folder.
    file="${SEGMENT_FOLDER_DEFAULT}/${1}/${1}.${extension}"
    [[ -f "$file" ]] && echo "${1}:${file}" && return

    # Pure file in the custom segment folder.
    file="${SEGMENT_FOLDER_CUSTOM}/${1}.${extension}"
    [[ -f "$file" ]] && echo "${1}:${file}" && return

    # Segment in a sub-directory of the custom folder.
    file="${SEGMENT_FOLDER_CUSTOM}/${1}/${1}.${extension}"
    [[ -f "$file" ]] && echo "${1}:${file}" && return
  fi
}
