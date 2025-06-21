run_command() {
    local cmd="$1"
    local key="$2"
    local tmp="$OUTPUT_DIR/${key}.json"
    temp_files+=("$tmp")
    echo "[DEBUG] Starting collection for $key..." | tee -a "$LOG_FILE"
    if timeout 300 bash -c "$cmd" > "$tmp" 2>>"$LOG_FILE"; then
        echo "[DEBUG] Finished collection for $key." | tee -a "$LOG_FILE"
        # Validate temp file exists and is valid JSON
        if [ -s "$tmp" ] && jq empty "$tmp" 2>/dev/null; then
            merge_json "$key" "$(cat "$tmp")"
        else
            echo "[DEBUG] $tmp missing or invalid JSON for $key, merging empty array/object." | tee -a "$LOG_FILE"
            merge_json "$key" "[]"
        fi
    else
        echo "[DEBUG] Error or timeout collecting $key, writing empty array." | tee -a "$LOG_FILE"
        merge_json "$key" "[]"
    fi
    echo "[DEBUG] Completed processing for $key." | tee -a "$LOG_FILE"
}