#!/bin/bash
#
# Aggregation of functions to aggregate content for the status line.
# Will be sourced by the SegmentHandler if available and enabled for the
# specific segment.
# By outsourcing this code, it makes the most segments, which does not
# abbreviate any content smaller in the memory.

# Get the configuration value for the abbreviation.
# This searches in first place for a segment customized definition.
# If such is not defined, the default value is returned.
#
# Arguments:
#   $1 - postfix of the configuration variable
#   $2 - name of the segment
#
# Returns:
#   either the customized or default configuration value
#
function getAbbreviationConfigValue {
  # Try to get segment custom configuration value.
  eval "value=\$${2^^}_ABBREVIATION_$1"
  
  # If no custom value is defined, get the default one.
  if [[ -z "$value" ]] ; then
    eval "value=\$ABBREVIATION_$1"
  fi

  echo "$value"
}

# Function to abbreviate a string value.
# Works on a set of different configuration values, which define the behavior.
# How long a string is allowed to be is configured.
# In case the given string is short enough, nothing happens.
# Else the string gets shorten, depending on the defined type.
# The mentioned type defines which part of the string gets cut and replaced
# with a placeholder.
# Furthermore this abbreviation can differ for each segment by customized
# configuration values.
#
# Arguments:
#   $1 - string to abbreviate
#   $2 - name of the segment this string is displayed
#
# Returns:
#   shorten string as abbreviation of the input
#
function abbreviate { 
  # Get the configuration values.
  length=$(getAbbreviationConfigValue "LENGTH" "$2")
  type=$(getAbbreviationConfigValue "TYPE" "$2")
  string=$(getAbbreviationConfigValue "STRING" "$2")

  # Do nothing in case its short enough.
  if [[ ${#1} -le ${length} ]] ; then
    echo "$1"

  else
    if [[ "${type}" = "middle" ]] ; then
      # Each part is half length of the whole defined length.
      partLength=$((length / 2)) 
      partTwoStart=$((${#1} - partLength - 1))
      
      # Cut out the parts.
      partOne=${1:0:partLength}
      partTwo=${1:partTwoStart}
  
      echo "${partOne}${string}${partTwo}"

    else
      echo "${1:0:length}${string}"
    fi
  fi
}
