#!/bin/bash

Wimer() {
    local tasks_completed=0
    local total_task_time=0
    local task_summary=""
    local breaks_completed=0
    local total_break_time=0
    local break_summary=""
    local ALARM_FILE="/usr/share/sounds/alarm.wav"
    local SUMMARY_FILE="$HOME/wimer_summary.txt"
    
    start_timer() {
        (
            for ((i = 0; i < $1; i++)); do
                percent=$(((i * 100) / $1))
                echo "$percent"
                remaining_seconds=$(($1 - i + 1))
                hours=$((remaining_seconds / 3600))
                minutes=$(((remaining_seconds % 3600) / 60))
                seconds=$((remaining_seconds % 60))
                
                if [ "$hours" -gt 0 ]; then
                    formatted_time="    Remaining time: $(printf "%02d:%02d:%02d" "$hours" "$minutes" "$seconds")"
                else
                    formatted_time="       Remaining time: $(printf "%02d:%02d" "$minutes" "$seconds")"
                fi
                
                echo "# <span><b>$formatted_time</b></span>"
                sleep 1
            done
        ) | zenity --progress --title="$2" --width=200 --height=200 --auto-close --percentage=0 --cancel-label="Stop" 2>/dev/null
    }
    
    handle_break() {
        local bmin=0
        break_choice=$(zenity --list --radiolist --title="Take a Break?" --text="Would you like a break?" \
            --column="Select" --column="Duration" \
            TRUE "5 minutes" FALSE "10 minutes" FALSE "Custom" \
        --height=380 --ok-label="Yes" --cancel-label="No" 2>/dev/null) || break_choice=""
        
        if [ $? -eq 0 ]; then
            case $break_choice in
                "5 minutes") bmin=5 ;;
                "10 minutes") bmin=10 ;;
                "Custom")
                    bmin=$(zenity --entry --title="Break Duration" --text="Enter break minutes" --ok-label="Start" --cancel-label="Cancel" 2>/dev/null) || bmin=0
                    [[ ! "$bmin" =~ ^[0-9]+$ ]] && bmin=0
                ;;
                *) bmin=0 ;;
            esac
            if [ "$bmin" -gt 0 ]; then
                run_break "$((bmin * 60))" "Break $((breaks_completed + 1))" "break"
            fi
        fi
    }
    
    run_task() {
        start_timer "$1" "$2"
        if [ $? -eq 0 ]; then
            zenity --notification --text="$2 Timer Finished." 2>/dev/null && aplay $ALARM_FILE 2>/dev/null
            write_summary "Task" "$2" "$(($1 / 3600))" "$((($1 % 3600) / 60))"
            tasks_completed=$((tasks_completed + 1))
            total_task_time=$((total_task_time + $1))
            handle_break
        fi
    }
    
    run_break() {
        start_timer "$1" "$2"
        if [ $? -eq 0 ]; then
            zenity --notification --text="$2 Timer Finished." 2>/dev/null && aplay $ALARM_FILE 2>/dev/null
            write_summary "Break" "$2" "$(($1 / 3600))" "$((($1 % 3600) / 60))"
            breaks_completed=$((breaks_completed + 1))
            total_break_time=$((total_break_time + $1))
        fi
    }
    
    process_task() {
        local total_seconds=$(($1 * 3600 + $2 * 60))
        if [ "$total_seconds" -le 0 ]; then
            return
        fi
        run_task "$total_seconds" "$3"
    }
    
    show_stats() {
        zenity --info --title="Task and Break Information" \
        --width=300 \
        --text="\
        <b>Tasks Completed:</b> $tasks_completed\n\
        ----------------------------------------\n\
        <b>Breaks Taken:</b> $breaks_completed\n\
        ----------------------------------------\n\
        <b>Total Tasks Time:</b> $((total_task_time / 3600))h $(( (total_task_time % 3600) / 60 ))m\n\
        ----------------------------------------\n\
        <b>Total Breaks Time:</b> $((total_break_time / 3600))h $(( (total_break_time % 3600) / 60 ))m" \
        2>/dev/null
    }
    
    write_summary() {
        if [ "$3" -eq 0 ]; then
            if [ "$1" == "Break" ]; then
                break_summary+="Name: $2, Time: ${4}m\n"
            else
                task_summary+="Name: $2, Time: ${4}m\n"
            fi
        else
            if [ "$1" == "Break" ]; then
                break_summary+="Name: $2, Time: ${3}h ${4}m\n"
            else
                task_summary+="Name: $2, Time: ${3}h ${4}m\n"
            fi
        fi
    }
    
    save_summary() {
        if [ -f "$SUMMARY_FILE" ]; then
            rm "$SUMMARY_FILE"
        fi
        echo -e "Overall Time: $(( (total_task_time + total_break_time) / 3600 ))h $(( ( (total_task_time + total_break_time) % 3600) / 60 ))m\n" >> "$SUMMARY_FILE"
        echo "Tasks Completed: $tasks_completed, Total Time: $((total_task_time / 3600))h $(((total_task_time % 3600) / 60))m" >> "$SUMMARY_FILE"
        echo -e "$task_summary" >> "$SUMMARY_FILE"
        echo "Breaks Taken: $breaks_completed, Total Breaks Time: $((total_break_time / 3600))h $(((total_break_time % 3600) / 60))m" >> "$SUMMARY_FILE"
        echo -e "$break_summary" >> "$SUMMARY_FILE"
    }
    
    parse_arguments() {
        while getopts ":n:h:m:" opt; do
            case $opt in
                n) name="$OPTARG" ;;
                h) hours="$OPTARG" ;;
                m) minutes="$OPTARG" ;;
            esac
        done
    }
    
    initialize_task() {
        name=${name:-""}
        hours=${hours:-0}
        minutes=${minutes:-0}
        
        if [[ -n "$name" || "$hours" -gt 0 || "$minutes" -gt 0 ]]; then
            task_name="${name:-Task $((tasks_completed + 1))}"
            process_task "$hours" "$minutes" "$task_name"
            name=""
            hours=0
            minutes=0
        fi
    }
    
    get_time_input() {
        local display_text=$1
        if [ "$tasks_completed" -gt 0 ]; then
            zenity --forms --title="Wimer" --text="$display_text" --width=350 \
            --add-entry="Name (optional)" \
            --add-entry="Hours" \
            --add-entry="Minutes" \
            --ok-label="Start" \
            --extra-button="Show Stats" \
            --cancel-label="Close" 2>/dev/null
        else
            zenity --forms --title="Wimer" --text="$display_text" --width=350 \
            --add-entry="Name (optional)" \
            --add-entry="Hours" \
            --add-entry="Minutes" \
            --ok-label="Start" \
            --cancel-label="Close" 2>/dev/null || exit 0
        fi
    }
    
    handle_time_input() {
        local time_input=$1
        if [[ "$time_input" == "" ]]; then
            if [ "$tasks_completed" -gt 0 ]; then
                exit_confirmation=$(zenity --question --text="Do you want to save the summary before exiting?" --ok-label="Yes" --cancel-label="No" 2>/dev/null)
                if [[ $? -eq 0 ]]; then
                    save_summary
                fi
            fi
            exit 0
            elif [[ "$time_input" == "Show Stats" ]]; then
            show_stats
            return
        fi
        
        task_name=$(echo "$time_input" | cut -d '|' -f1)
        hours=$(echo "$time_input" | cut -d '|' -f2)
        minutes=$(echo "$time_input" | cut -d '|' -f3)
        
        if ! validate_time_input; then
            return 1
        fi
        
        process_task "$hours" "$minutes" "$task_name"
    }
    
    validate_time_input() {
        [[ ! "$hours" =~ ^[0-9]+$ ]] && [ -n "$hours" ] && hours=""
        [[ ! "$minutes" =~ ^[0-9]+$ ]] && [ -n "$minutes" ] && minutes=""
        [ -z "$task_name" ] && task_name="Task $((tasks_completed + 1))"
        [ -z "$hours" ] && hours=0
        [ -z "$minutes" ] && minutes=0
        
        if [[ "$hours" -ge 24 && "$minutes" -ne 0 ]] || [[ "$minutes" -ge 60 && "$hours" -ge 24 ]]; then
            return 1
        fi
        return 0
    }
    
    usage() {
        echo "Usage: $0 [-n name] [-h hours] [-m minutes]"
        exit 1
    }
    
    run() {
        case $1 in
            --help)
                usage
                return
            ;;
        esac
        
        if ! command -v zenity &>/dev/null; then
            echo "Zenity is not installed. Please install it and try again."
            exit 1
        fi
        
        parse_arguments "$@"
        initialize_task
        
        while true; do
            display_text="Set Task Name and Duration"
            time_input=$(get_time_input "$display_text")
            handle_time_input "$time_input"
        done
    }
    
    run "$@"
}

Wimer "$@"