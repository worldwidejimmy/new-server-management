#!/bin/bash

# Check if .env files are in sync with app-registry.json
# Returns human-readable output, suitable for CI or manual runs

REGISTRY_FILE="/home/ubuntu/apps/app-registry.json"
APPS_DIR="/home/ubuntu/apps"

if [ ! -f "$REGISTRY_FILE" ]; then
    echo '{"error": "Registry file not found"}'
    exit 1
fi

# Parse registry and check each app
check_app() {
    local app_name="$1"
    local mode="$2"
    local expected_port="$3"
    local app_path="$4"
    
    if [ "$expected_port" = "null" ] || [ -z "$expected_port" ]; then
        return
    fi
    
    local env_file="$app_path/.env"
    
    if [ ! -f "$env_file" ]; then
        echo "MISSING: $app_name ($mode) - Expected port $expected_port but .env file not found at $env_file"
        return 1
    fi
    
    local actual_port=$(grep "^PORT=" "$env_file" | cut -d'=' -f2)
    
    if [ "$actual_port" != "$expected_port" ]; then
        echo "MISMATCH: $app_name ($mode) - Registry says $expected_port but .env has $actual_port"
        return 1
    fi
    
    echo "OK: $app_name ($mode) - Port $expected_port matches"
    return 0
}

# Use jq if available
if command -v jq &> /dev/null; then
    while IFS= read -r line; do
        # line will be: name mode port path
        read -r name mode port path <<<"$line"
        check_app "$name" "$mode" "$port" "$path"
    done < <(jq -r '.apps | to_entries[] | .key as $slug | .value | {name: $slug, mode: "dev", port: .dev.port, path: .dev.path}, {name: $slug, mode: "prod", port: .prod.port, path: .prod.path} | [.name,.mode,.port,.path] | @tsv' "$REGISTRY_FILE")
else
    # Fallback parsing similar to original script
    echo "Checking apps from registry (jq not installed)..."
    for dir in "$APPS_DIR"/*.dev; do
        if [ -d "$dir" ]; then
            app_name=$(basename "$dir" .dev)
            expected_port=$(grep -A 20 "\"$app_name\"" "$REGISTRY_FILE" | grep -A 5 '"dev"' | grep '"port"' | head -1 | grep -oP '\\d+' | head -1)
            if [ -n "$expected_port" ] && [ "$expected_port" != "null" ]; then
                check_app "$app_name" "dev" "$expected_port" "$dir"
            fi
        fi
    done

    for dir in "$APPS_DIR"/*.prod; do
        if [ -d "$dir" ]; then
            app_name=$(basename "$dir" .prod)
            expected_port=$(grep -A 20 "\"$app_name\"" "$REGISTRY_FILE" | grep -A 5 '"prod"' | head -1 | grep '"port"' | grep -oP '\\d+' | head -1)
            if [ -n "$expected_port" ] && [ "$expected_port" != "null" ]; then
                check_app "$app_name" "prod" "$expected_port" "$dir"
            fi
        fi
    done
fi


echo ""
echo "Check complete!"
