#!/bin/bash

TASK_FILE="tasks.txt"
DELIM="|"

[[ ! -f $TASK_FILE ]] && touch $TASK_FILE

# ========== Colors ==========
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
CYAN="\033[0;36m"
NC="\033[0m"

# ========== Utility Functions ==========

generate_id() {
    if [[ ! -s $TASK_FILE ]]; then
        echo 1
    else
        awk -F"$DELIM" 'END{print $1+1}' "$TASK_FILE"
    fi
}

validate_priority() {
    [[ "$1" =~ ^(high|medium|low)$ ]]
}

validate_status() {
    [[ "$1" =~ ^(pending|in-progress|done)$ ]]
}

validate_date() {
    date -d "$1" +"%Y-%m-%d" >/dev/null 2>&1
}

task_exists() {
    grep -q "^$1$DELIM" "$TASK_FILE"
}

print_header() {
    echo -e "${CYAN}"
    printf "%-5s %-30s %-10s %-12s %-12s\n" "ID" "Title" "Priority" "Due Date" "Status"
    echo "--------------------------------------------------------------------------"
    echo -e "${NC}"
}

# ========== CRUD ==========

add_task() {
    echo -e "${BLUE}--- Add Task ---${NC}"

    read -p "Title: " title
    [[ -z "$title" ]] && { echo -e "${RED}Title cannot be empty!${NC}"; return; }

    if [[ "$title" == *"$DELIM"* ]]; then
        echo -e "${RED}Title cannot contain | character${NC}"
        return
    fi

    read -p "Priority (high/medium/low): " priority
    validate_priority "$priority" || { echo -e "${RED}Invalid priority!${NC}"; return; }

    read -p "Due Date (YYYY-MM-DD): " due
    validate_date "$due" || { echo -e "${RED}Invalid date!${NC}"; return; }

    id=$(generate_id)
    echo "$id$DELIM$title$DELIM$priority$DELIM$due$DELIM pending" >> "$TASK_FILE"

    echo -e "${GREEN}Task Added Successfully ✔${NC}"
}

list_tasks() {
    echo -e "${BLUE}--- All Tasks ---${NC}"
    print_header
    awk -F"$DELIM" '{printf "%-5s %-30s %-10s %-12s %-12s\n",$1,$2,$3,$4,$5}' "$TASK_FILE"
}

update_task() {
    read -p "Enter Task ID to update: " id
    task_exists "$id" || { echo -e "${RED}Task not found!${NC}"; return; }

    old=$(grep "^$id$DELIM" "$TASK_FILE")
    IFS="$DELIM" read -r oid otitle opriority odue ostatus <<< "$old"

    echo "Press Enter to keep old value"

    read -p "New Title [$otitle]: " title
    read -p "New Priority [$opriority]: " priority
    read -p "New Due Date [$odue]: " due
    read -p "New Status [$ostatus]: " status

    title=${title:-$otitle}
    priority=${priority:-$opriority}
    due=${due:-$odue}
    status=${status:-$ostatus}

    validate_priority "$priority" || { echo -e "${RED}Invalid priority!${NC}"; return; }
    validate_status "$status" || { echo -e "${RED}Invalid status!${NC}"; return; }
    validate_date "$due" || { echo -e "${RED}Invalid date!${NC}"; return; }

    sed -i "s/^$id$DELIM.*/$id$DELIM$title$DELIM$priority$DELIM$due$DELIM$status/" "$TASK_FILE"

    echo -e "${GREEN}Task Updated Successfully ✔${NC}"
}

delete_task() {
    read -p "Enter Task ID to delete: " id
    task_exists "$id" || { echo -e "${RED}Task not found!${NC}"; return; }

    read -p "Are you sure? (y/n): " confirm
    [[ "$confirm" != "y" ]] && return

    sed -i "/^$id$DELIM/d" "$TASK_FILE"
    echo -e "${GREEN}Task Deleted ✔${NC}"
}

search_task() {
    read -p "Enter keyword: " keyword
    print_header
    grep -i "$keyword" "$TASK_FILE" | \
    awk -F"$DELIM" '{printf "%-5s %-30s %-10s %-12s %-12s\n",$1,$2,$3,$4,$5}'
}

# ========== Reports ==========

task_summary() {
    echo -e "${YELLOW}--- Task Summary ---${NC}"
    echo "Pending: $(grep -c "|pending" "$TASK_FILE")"
    echo "In-Progress: $(grep -c "|in-progress" "$TASK_FILE")"
    echo "Done: $(grep -c "|done" "$TASK_FILE")"
}

overdue_tasks() {
    echo -e "${RED}--- Overdue Tasks ---${NC}"
    print_header

    today=$(date +%s)

    while IFS="$DELIM" read -r id title priority due status
    do
        due_ts=$(date -d "$due" +%s 2>/dev/null)
        if [[ $due_ts -lt $today && "$status" != "done" ]]; then
            printf "%-5s %-30s %-10s %-12s %-12s\n" "$id" "$title" "$priority" "$due" "$status"
        fi
    done < "$TASK_FILE"
}

priority_report() {
    echo -e "${CYAN}--- High Priority ---${NC}"
    grep "|high|" "$TASK_FILE"
    echo
    echo -e "${CYAN}--- Medium Priority ---${NC}"
    grep "|medium|" "$TASK_FILE"
    echo
    echo -e "${CYAN}--- Low Priority ---${NC}"
    grep "|low|" "$TASK_FILE"
}

# ========== Export ==========

export_csv() {
    if [[ ! -s $TASK_FILE ]]; then
        echo -e "${RED}No tasks to export!${NC}"
        return
    fi

    echo "ID,Title,Priority,DueDate,Status" > tasks.csv
    sed "s/$DELIM/,/g" "$TASK_FILE" >> tasks.csv

    echo -e "${GREEN}Tasks exported successfully to tasks.csv ✔${NC}"
}

# ========== Menu ==========

while true; do
    echo -e "\n${BLUE}====== Mini Task Manager ======${NC}"
    echo "1) Add Task"
    echo "2) List Tasks"
    echo "3) Update Task"
    echo "4) Delete Task"
    echo "5) Search Task"
    echo "6) Task Summary"
    echo "7) Overdue Tasks"
    echo "8) Priority Report"
    echo "9) Export to CSV"
    echo "10) Exit"

    read -p "Choose: " choice

    case $choice in
        1) add_task ;;
        2) list_tasks ;;
        3) update_task ;;
        4) delete_task ;;
        5) search_task ;;
        6) task_summary ;;
        7) overdue_tasks ;;
        8) priority_report ;;
        9) export_csv ;;
        10) echo "Goodbye 👋"; exit ;;
        *) echo -e "${RED}Invalid Option${NC}" ;;
    esac
done
