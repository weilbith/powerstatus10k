#!/bin/bash
#
# Process which reads continuously from the FIFO waiting for updates.
# It holds an array with a format string for each segment.
# An FIFO entry is suffixed by the segment orientation and index, which is equal
# to the array index.
# Pass the concatenation of all segments format strings to the standard output.


# Parse given arguments or use defaults.
[[ -n "$1" ]] && list_length_left=$1 || list_length_left=1
[[ -n "$2" ]] && list_length_center=$1 || list_length_center=1
[[ -n "$3" ]] && list_length_right=$1 || list_length_right=1

# Arrays which holds the current format string for each orientation segments.
declare -a format_string_list_left=( "$(for (( i=1; i<=list_length_left; i++ )); do echo ""; done )" )
declare -a format_string_list_center=( "$(for (( i=1; i<=list_length_center; i++ )); do echo ""; done )" )
declare -a format_string_list_right=( "$(for (( i=1; i<=list_length_right; i++ )); do echo ""; done )" )


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
