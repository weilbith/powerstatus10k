#!/bin/bash

# Load the default and user configurations.
source $(dirname $0)/default.conf # Default values for all necessary variables.
source $(dirname $0)/custom.conf # Load after default values to be able to overwrite them.


# Define deviated variables.
[[ "$BOTTOM" = true ]] && BAR_BOTTOM_ARG="-b"


# Variables (load here to make sure they overwrite users configurations if necessary)
FIFO="/tmp/i3_planetbar" # The fifo used to pass content to the lemonbar.


# Load the fonts
xset fp+ $HOME/.fonts/terminesspowerline


# Prepare the fifo.
rm -f "${FIFO}" # Make sure to delete a possible old fifo.
mkfifo "${FIFO}" # Create the fifo.


# Function which writes the content to the fifo.
#
function writing {
  # Initialize the counter.
  counter=0

  # Keep open endles loop as long as the process is running.
  while true ; do
    # Increase the counter to have some effect.
    counter=$(($counter+1))
    
    # Format the content for the lemonbar and write it to the fifo.
    firstRightBg="#ff0000"  
    firstRightFg="#ffffff"
    secondRightBg="#0000ff"
    secondRightFg="#ffffff"
    firstRightSeg="%{r}%{B${secondRightBg} F${firstRightBg}}${SEGMENT_SEPARATOR_RIGHT_OUTER}%{B${firstRightBg} F${firstRightFg}} T %{F- B-}"
    secondRightSeg="%{r}%{B${DEFAULT_BACKGROUND} F${secondRightBg}}${SEGMENT_SEPARATOR_RIGHT_OUTER}%{F${secondRightFg} B${secondRightBg}} ${counter} %{F- B-}"
    printf "%s\n" "${secondRightSeg}    ${firstRightSeg}" > "${FIFO}" &
   
    # Delay until update the content.
    sleep 1s
  done
}


# Function which read from the fifo.
#
function reading {
  # Keep open endless loop as long as the process is running.
  while true ; do
    # Wait until fifo has content.
    if read line < /tmp/i3_planetbar ; then
      # Echo content to pass it to the lemonbar by the process chain.
      echo "${line}"
    fi
  done
}


# Start the process chain with writing/reading the fifo and pass it to the powerline.
writing & # Write content to the buffer in background.
reading | # Read content from the buffer in background.
$(dirname $0)/lemonbar -p -d "$BAR_BOTTOM_ARG" -f "$FONT_DEFAULT:size=$FONT_SIZE" -B "$DEFAULT_BACKGROUND" -F "$DEFAULT_FOREGROUND" -g "x$HEIGHT" & # Run lemonbar in background and read standard output from the reading function.
wait # Wait here and do not end (useful for debugging, else just sent to background on call)
