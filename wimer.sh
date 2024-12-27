#!/bin/bash
WorkTimer() {
    local tasksCompleted=0
    local breaksTaken=0
    local totalTaskTime=0
    local totalBreakTime=0
    ALARM_FILE="/usr/share/sounds/alarm.wav"
    
    run_timer() {
        local total_seconds=$1
        local title=$2
        local type=$3
        if [ "$total_seconds" -le 0 ]; then
            return
        fi
        totalTaskTime=$((totalTaskTime + total_seconds))
        
        (
            for ((i = 0; i <= total_seconds; i++)); do
                percent=$(((i * 100) / total_seconds))
                echo "$percent"
                case "$title" in
                    "Break $((breaksTaken + 1))")
                        formatted_time="$(printf "%02d:%02d" $(((total_seconds - i) / 60)) $(((total_seconds - i) % 60)))"
                    ;;
                    *)
                        formatted_time="$(printf "%02d:%02d:%02d" $(((total_seconds - i) / 3600)) $(((total_seconds - i) % 3600 / 60)) $(((total_seconds - i) % 60)))"
                    ;;
                esac
                
                echo "# <span><b>   Remaining time: $formatted_time</b></span>"
                sleep 1
            done
        ) | zenity --progress --title="$title" --width=200 --height=200 --auto-close --percentage=0 --cancel-label="Stop" 2>/dev/null
        
        if [ $? -eq 0 ]; then
            zenity --notification --text="$title timer finished." 2>/dev/null && aplay $ALARM_FILE 2>/dev/null
            if [ "$type" == "task" ]; then
                tasksCompleted=$((tasksCompleted + 1))
                breakChoice=$(zenity --list --radiolist --title="Take a Break?" --text="Would you like a break?" \
                    --column="Select" --column="Duration" \
                    TRUE "5 minutes" FALSE "10 minutes" FALSE "Custom" \
                --height=380 --ok-label="Yes" --cancel-label="No" 2>/dev/null) || breakChoice=""
                
                if [ $? -eq 0 ]; then
                    case $breakChoice in
                        "5 minutes") bmin=5 ;;
                        "10 minutes") bmin=10 ;;
                        "Custom")
                            bmin=$(zenity --entry --title="Break Duration" --text="Enter break minutes" --ok-label="Start" --cancel-label="Cancel" 2>/dev/null) || bmin=0
                            [[ ! "$bmin" =~ ^[0-9]+$ ]] && bmin=0
                        ;;
                        *) bmin=0 ;;
                    esac
                    totalBreakTime=$((totalBreakTime + bmin * 60))
                    run_timer "$((bmin * 60))" "Break $((breaksTaken + 1))" "break"
                fi
                elif [ "$title" == "Break $((breaksTaken + 1))" ]; then
                breaksTaken=$((breaksTaken + 1))
            fi
        fi
    }
    
    countdown() {
        local hours=$1
        local minutes=$2
        local taskName=$3
        local total_seconds=$((hours * 3600 + minutes * 60))
        
        run_timer "$total_seconds" "$taskName" "task"
    }
    
    showStats() {
        totalTaskHours=$((totalTaskTime / 3600))
        totalTaskMinutes=$(( (totalTaskTime % 3600) / 60 ))
        totalTaskSeconds=$((totalTaskTime % 60))
        
        totalBreakHours=$((totalBreakTime / 3600))
        totalBreakMinutes=$(( (totalBreakTime % 3600) / 60 ))
        totalBreakSeconds=$((totalBreakTime % 60))
        
        zenity --info --title="Task and Break Information" \
        --width=300 \
        --text="\
        <b>Tasks Completed:</b> $tasksCompleted\n\
        ---------------------------------------------\n\
        <b>Breaks Taken:</b> $breaksTaken\n\
        ---------------------------------------------\n\
        <b>Total Task Time Spent:</b> ${totalTaskHours}h ${totalTaskMinutes}m\n\
        ---------------------------------------------\n\
        <b>Total Break Time Taken:</b> ${totalBreakHours}h ${totalBreakMinutes}m" \
        2>/dev/null
    }
    
    start() {
        if ! command -v zenity &>/dev/null; then
            echo "Zenity is not installed. Please install it and try again."
            exit 1
        fi
        
        usage() {
            echo "Usage: $0 [-n name] [-h hours] [-m minutes]"
            exit 1
        }
        
        if [ "$1" == '-h' ]; then
            usage
        fi
        
        while getopts ":n:h:m:" opt; do
            case $opt in
                n)
                    name="$OPTARG"
                ;;
                h)
                    hours="$OPTARG"
                ;;
                m)
                    minutes="$OPTARG"
                ;;
            esac
        done
        
        name=${name:-""}
        hours=${hours:-0}
        minutes=${minutes:-0}
        
        if [[ -n "$name" || "$hours" -gt 0 || "$minutes" -gt 0 ]]; then
            taskName="${name:-Task $((tasksCompleted + 1))}"
            countdown "$hours" "$minutes" "$taskName"
            name=""
            hours=0
            minutes=0
        fi
        
        while true; do
            displayText="Set Task Name and Duration"
            if [ "$tasksCompleted" -gt 0 ]; then
                timeInput=$(zenity --forms --title="Work Timer" --text="$displayText" --width=350 \
                    --add-entry="Name (optional)" \
                    --add-entry="Hours" \
                    --add-entry="Minutes" \
                    --extra-button="Show Stats" \
                    --ok-label="Start" \
                --cancel-label="Exit" 2>/dev/null)
                if [[ "$timeInput" == "" ]]; then
                    exit 0
                    elif [[ "$timeInput" == "Show Stats" ]]; then
                    showStats
                fi
            else
                timeInput=$(zenity --forms --title="Work Timer" --text="$displayText" --width=350 \
                --add-entry="Name (optional)" --add-entry="Hours" --add-entry="Minutes" --ok-label="Start" --cancel-label="Exit" 2>/dev/null) || exit 0
            fi
            n=$(echo "$timeInput" | cut -d '|' -f1)
            h=$(echo "$timeInput" | cut -d '|' -f2)
            m=$(echo "$timeInput" | cut -d '|' -f3)
            
            
            [[ ! "$h" =~ ^[0-9]+$ ]] && [ -n "$h" ] && h=""
            [[ ! "$m" =~ ^[0-9]+$ ]] && [ -n "$m" ] && m=""
            [ -z "$n" ] && n="Task $((tasksCompleted + 1))"
            [ -z "$h" ] && h=0
            [ -z "$m" ] && m=0
            
            if [[ "$h" -ge 24 && "$m" -ne 0 ]] || [[ "$m" -ge 60 && "$h" -ne 0 ]]; then
                continue
            fi
            
            countdown "$h" "$m" "$n"
        done
    }
    
    start "$@"
}

WorkTimer "$@"
