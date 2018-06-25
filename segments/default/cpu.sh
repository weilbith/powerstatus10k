#!/bin/bash
#
# PowerStatus10k segment.
# Segment displays the current average CPU usage.
# This segment is still buggy, cause the stored values doesn't work.

# Calculation variables.
CPU_PREV_TOTAL=0
CPU_PREV_IDLE=0

# Implement the interface function to get the current state.
#
function getState_cpu {
  cpu=$(cat /proc/stat | grep -o -P '(?<=cpu ).*') # Get the total CPU statistics.
  idle=$(echo $cpu | cut -d ' ' -f 4) # Get the idle CPU time.

  # Calculate the total CPU time.
  total=0

  for value in $cpu ; do
    total=$((total + value))
  done

  # Calculate the CPU usage since we last checked.
  diff_total=$((total - CPU_PREV_TOTAL))
  diff_idle=$((idle - CPU_PREV_IDLE))

  # echo total $diff_total idle $diff_idle
  diff_usage=$(((1000 * (diff_total - diff_idle) / diff_total + 5) / 10))

  # Remember the total and idle CPU times for the next check.
  CPU_PREV_TOTAL="$total"
  CPU_PREV_IDLE="$idle"

  # Build the state string.
  echo "${CPU_ICON} ${diff_usage}%"
}
