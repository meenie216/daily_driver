#!/bin/bash

# Stack management script
# Usage: ./stack_manager.sh [command] [item]


STACK_PATH="${STACK_PATH:-$HOME/.stack}"
STACK_FILE=${STACK_PATH}/in_progress
COMPLETED_FILE=${STACK_PATH}/done

# Function to display usage
usage() {
    echo "Usage: $0 {add|pop|list|promote|done|clear_done} [item]"
    echo "  add        - Add item to stack (with timestamp)"
    echo "  pop        - Remove and display top item.  Top item is added to the done list"
    echo "  list       - Display all items in stack"
    echo "  promote    - Move item to top of stack"
    echo "  done       - List items in the current done file"
    echo "  clear_done - Clears the done list.  Previous done list is date prefixed and retained"

    exit 1
}

# Function to check if stack file exists, create if not
function check_stack_file {
    mkdir -p $STACK_PATH

    if [ ! -f "$STACK_FILE" ]; then
        touch "$STACK_FILE"
    fi
}

# Function to add item to stack
function add {
    local item="$@"
    if [ -z "$item" ]; then
        echo "Error: Item cannot be empty"
        exit 1
    fi
    
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo "$timestamp|$item" >> "$STACK_FILE"
    echo "Added item to stack: $item"
}

# Function to pop item from stack
function pop {
    check_stack_file
    
    if [ ! -s "$STACK_FILE" ]; then
        echo "Stack is empty"
        return 1
    fi
    
    # Get the last line (top of stack)
    local top_item=$(tail -n 1 "$STACK_FILE")
    
    # Remove the last line from file
    sed -i '$d' "$STACK_FILE"
    
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo "$timestamp|$top_item" >> "$COMPLETED_FILE"

    # Extract item name (remove timestamp)
    local item_name="${top_item#*|}"
    echo "Popped item: $item_name"
}

function list {
    check_stack_file
    
    if [ ! -s "$STACK_FILE" ]; then
        echo "Stack is empty"
        return 1
    fi
    
    echo "To do:"
    echo "==============================="
    # Display from top to bottom (reverse order)
    tac "$STACK_FILE" | cat -n
}

function done {
    check_stack_file
    
    if [ ! -s "$COMPLETED_FILE" ]; then
        echo "Stack is empty"
        return 1
    fi
    
    echo "Done:"
    echo "==============================="
    # Display from top to bottom (reverse order)
    tac "$COMPLETED_FILE" | cat -n
}

function clear_done {
    if [ ! -s "$COMPLETED_FILE" ]; then
        echo "Done list is already clear"
        return 1
    fi
    local timestamp=$(date +"%Y%m%dT%H:%M:%S")
    mv $COMPLETED_FILE $STACK_PATH/$timestamp.done
}

function promote {
    local line_number="$1"
    
    if [ -z "$line_number" ]; then
        echo "Error: Line number cannot be empty"
        exit 1
    fi
    
    # Check if line_number is a valid number
    if ! [[ "$line_number" =~ ^[0-9]+$ ]]; then
        echo "Error: Line number must be a positive integer"
        exit 1
    fi
    
    check_stack_file
    
    if [ ! -s "$STACK_FILE" ]; then
        echo "Stack is empty"
        return 1
    fi
    
    # Count total lines to validate line number
    local total_lines=$(wc -l < "$STACK_FILE")
    
    if [ "$line_number" -lt 1 ] || [ "$line_number" -gt "$total_lines" ]; then
        echo "Error: Line number $line_number is out of range (1-$total_lines)"
        exit 1
    fi
    
    # The list shows items from top to bottom, with line numbers starting from 1
    # So line 1 in the list represents the TOP of stack
    # Line N in the list represents the BOTTOM of stack
    
    # In the file, the first line is the bottom of stack (oldest)
    # The last line is the top of stack (newest)
    
    # We need to find which line in the file corresponds to the requested line number
    # Since list shows reverse order, line N from list = line (total_lines - N + 1) in file
    
    local file_line_number=$((total_lines - line_number + 1))
    
    # Get the specific line content (convert to 0-based index for sed)
    local target_line=$(sed -n "${file_line_number}p" "$STACK_FILE")
    
    # Extract timestamp and item name
    local timestamp="${target_line%|*}"
    local item_name="${target_line#*|}"
    
    # Remove the specific line from file
    sed -i "${file_line_number}d" "$STACK_FILE"
    
    # Add the item back to the end (top of stack)
    echo "$timestamp|$item_name" >> "$STACK_FILE"
    
    echo "Promoted item to top: $item_name"
}

function default {
  help
}

function help {
  echo "$0 <task> <args>"
  echo "Tasks:"
  compgen -A function | cat -n
}

TIMEFORMAT="Task completed in %3lR"
time ${@:-default}