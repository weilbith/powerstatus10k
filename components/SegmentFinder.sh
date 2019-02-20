#!/bin/bash

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
  getSegmentPart "$1" "$IMPLEMENTATION"
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
  getSegmentPart "$1" "$CONFIGURATION"
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
    directory="${POWERSTATUS10K_DIR_SEGMENTS_USER}/${name}"

    # Get the repository if it does not exist yet.
    if [[ ! -d "$POWERSTATUS10K_DIR_SEGMENTS_USER" ]] || \
      [[ ! -d "${POWERSTATUS10K_DIR_SEGMENTS_USER}/${name}" ]] ; then
      mkdir -p "$POWERSTATUS10K_DIR_SEGMENTS_USER"  
      url="https://github.com/${1}.git"
      git clone --depth 1 "$url" "$directory" &> /dev/null
    
    # Update the existing repository.
    else
      git -C "$directory" pull --force &> /dev/null
    fi

    

    # Define the possible files for the requested type.
    file="${POWERSTATUS10K_DIR_SEGMENTS_USER}/${name}/${name}.${extension}"
    file_pure="${POWERSTATUS10K_DIR_SEGMENTS_USER}/${name}/${name_pure}.${extension}"

    # Check if the file exist to return it.
    # Else the response will leave empty.
    [[ -f "$file" ]] && echo "${name}:${file}" && return
    [[ -f "$file_pure" ]] && echo "${name_pure}:${file_pure}" && return

  # Segment as pure file or sub-directory.
  else
    echo "${POWERSTATUS10K_DIR_SEGMENTS_GLOBAL}" > test.log
    # Pure file in the default segment folder.
    file="${POWERSTATUS10K_DIR_SEGMENTS_GLOBAL}/${1}.${extension}"
    [[ -f "$file" ]] && echo "${1}:${file}" && return

    # Segment in a sub-directory of the default folder.
    file="${POWERSTATUS10K_DIR_SEGMENTS_GLOBAL}/${1}/${1}.${extension}"
    [[ -f "$file" ]] && echo "${1}:${file}" && return

    # Pure file in the custom segment folder.
    file="${POWERSTATUS10K_DIR_SEGMENTS_USER}/${1}.${extension}"
    [[ -f "$file" ]] && echo "${1}:${file}" && return

    # Segment in a sub-directory of the custom folder.
    file="${POWERSTATUS10K_DIR_SEGMENTS_USER}/${1}/${1}.${extension}"
    [[ -f "$file" ]] && echo "${1}:${file}" && return
  fi
}
