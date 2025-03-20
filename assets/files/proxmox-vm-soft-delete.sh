#!/bin/bash
log_message() {
  local message=$1
  local timestamp=$(TZ='Asia/Jakarta' date +"%Y-%m-%dT%H:%M:%S%:z")
  echo "$timestamp - \"$message\"" | tee -a /var/log/pve/cleanup-vm-terminate.log
}

# Define current hostname
node_hostname=$(hostname -s)

# Initialize count of deleted VMs
deleted_vms_count=0

# Get the list of VM IDs from the pool in current host only
vmid_list=$(pvesh get /pools/TERMINATED --output-format json | jq --arg node_name "$node_hostname" '.members[] | select(.node == $node_name) | .vmid')

for vmid in $vmid_list; do
    description=$(pvesh get /nodes/$node_hostname/qemu/$vmid/config --output-format json | jq -r .description | jq -r .terminated_at)

    # Check if description exists and matches the expected format including timezone e.g 2025-03-21T01:12:05+07:00
    if [[ $description =~ ([0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}\+[0-9]{2}:[0-9]{2}) ]]; then
        # Extract the date with timezone from the description using regex
        terminated_date="${BASH_REMATCH[1]}"

        # Convert the terminated date to a Unix timestamp and calculate the difference
        terminated_timestamp=$(date -d "$terminated_date" +%s)
        current_timestamp=$(date +%s)
        diff_days=$(( (current_timestamp - terminated_timestamp) / 86400 ))

        if (( diff_days > 3 )); then
            log_message "VM $vmid is older than 3 days. Deleting VM and RRD data..."
            pvesh delete /nodes/$node_hostname/qemu/$vmid

            node_list=$(pvesh get /nodes --output-format json | jq -r .[].node)
            for nodelist in $node_list; do
                log_message "rrdcache cleanup process for vm $vmid on node $nodelist"
                ssh "$nodelist" "rm -rf /var/lib/rrdcached/db/pve2-vm/$vmid"
            done

            log_message "VM $vmid has been deleted."
            ((deleted_vms_count++))

            sleep 120s
        else
            echo "VM $vmid is not older than 3 days, skipping process."
        fi
    else
        log_message "Description for VM $vmid not found or not in the expected format."
    fi
done

# Final log message after all checks
log_message "The task of cleaning up the $deleted_vms_count terminated VM is complete"