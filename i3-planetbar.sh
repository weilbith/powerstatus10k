#!/bin/bash

# Variables
FIFO="/tmp/i3_planetbar" # The fifo used to pass content to the lemonbar.


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
    printf "%s\n" "%{r}%{F#000000} ${counter} %{F- B-}" > "${FIFO}" &
   
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
lemonbar -p -g x30 -B "#ffffff" -F "#000000" & # Run lemonbar in background and read standard output from the reading function.
wait # Wait here and do not end (useful for debugging, else just sent to background on call)
