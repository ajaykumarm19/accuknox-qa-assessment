#!/usr/bin/env bash

set -euo pipefail

# Configurable Thresholds
CPU_THRESHOLD=80
MEM_THRESHOLD=80
DISK_THRESHOLD=85
PROC_THRESHOLD=300

# Log file setup (uses /var/log if writable, otherwise local directory)
LOG_FILE="/var/log/system_health.log"
if ! touch "$LOG_FILE" 2>/dev/null; then
    LOG_FILE="./system_health.log"
fi

log_message() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

# 1. Calculate CPU Usage (%) over a 1-second sample from /proc/stat
get_cpu_usage() {
    read -r _ user1 nice1 system1 idle1 iowait1 irq1 softirq1 steal1 _ < /proc/stat
    local total1=$((user1 + nice1 + system1 + idle1 + iowait1 + irq1 + softirq1 + steal1))
    local idle_all1=$((idle1 + iowait1))

    sleep 1

    read -r _ user2 nice2 system2 idle2 iowait2 irq2 softirq2 steal2 _ < /proc/stat
    local total2=$((user2 + nice2 + system2 + idle2 + iowait2 + irq2 + softirq2 + steal2))
    local idle_all2=$((idle2 + iowait2))

    local total_diff=$((total2 - total1))
    local idle_diff=$((idle_all2 - idle_all1))

    if [ "$total_diff" -eq 0 ]; then
        echo 0
    else
        echo $(( (100 * (total_diff - idle_diff)) / total_diff ))
    fi
}

# 2. Calculate Memory Usage (%)
get_mem_usage() {
    free | awk '/^Mem:/ {printf "%.0f", ($3/$2) * 100}'
}

# 3. Calculate Root Disk Usage (%)
get_disk_usage() {
    df -P / | awk 'NR==2 {gsub("%", "", $5); print $5}'
}

# 4. Count Running Processes
get_process_count() {
    ps -e --no-headers | wc -l | tr -d ' '
}

main() {
    local alerts=0

    cpu_usage=$(get_cpu_usage)
    mem_usage=$(get_mem_usage)
    disk_usage=$(get_disk_usage)
    proc_count=$(get_process_count)

    log_message "INFO" "Health Check — CPU: ${cpu_usage}%, Memory: ${mem_usage}%, Disk (/): ${disk_usage}%, Processes: ${proc_count}"

    if [ "$cpu_usage" -gt "$CPU_THRESHOLD" ]; then
        log_message "ALERT" "High CPU usage detected: ${cpu_usage}% (Threshold: ${CPU_THRESHOLD}%)"
        alerts=$((alerts + 1))
    fi

    if [ "$mem_usage" -gt "$MEM_THRESHOLD" ]; then
        log_message "ALERT" "High Memory usage detected: ${mem_usage}% (Threshold: ${MEM_THRESHOLD}%)"
        alerts=$((alerts + 1))
    fi

    if [ "$disk_usage" -gt "$DISK_THRESHOLD" ]; then
        log_message "ALERT" "High Disk usage detected on /: ${disk_usage}% (Threshold: ${DISK_THRESHOLD}%)"
        alerts=$((alerts + 1))
    fi

    if [ "$proc_count" -gt "$PROC_THRESHOLD" ]; then
        log_message "ALERT" "High running process count: ${proc_count} (Threshold: ${PROC_THRESHOLD})"
        alerts=$((alerts + 1))
    fi

    if [ "$alerts" -eq 0 ]; then
        log_message "OK" "All system metrics are within healthy thresholds."
    else
        log_message "WARN" "Total threshold breaches detected: ${alerts}"
        exit 1
    fi
}

main
