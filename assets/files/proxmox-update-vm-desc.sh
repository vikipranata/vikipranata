#!/bin/bash
log_message() {
  local message=$1
  local timestamp=$(TZ='Asia/Jakarta' date +"%Y-%m-%dT%H:%M:%S%:z")
  echo "$timestamp - \"$message\"" | tee -a /var/log/pve/cleanup-vm-terminate.log
}

# Define current hostname
node_hostname=$(hostname -s)

# Initialize count of updated VMs
updated_vms_count=0

# Get VMID list retrieved from the current host
vmid_list=$(pvesh get /nodes/$(hostname -s)/qemu --output-format json | jq -r .[].vmid)
for vmid in $vmid_list; do
    log_message "get current VM $vmid description"
    description=$(pvesh get /nodes/$node_hostname/qemu/$vmid/config --output-format json | jq -r .description)

    if echo "$description" | jq -e 'has("template") and has("terminated_at")' &> /dev/null; then
        log_message "VM $vmid description is already in the correct json format"
    elif [ "$description" == "null" ] || [ -z "$description" ]; then
        log_message "Current VM $vmid description is null or empty"
        pvesh set /nodes/$node_hostname/qemu/$vmid/config --description "{\"template\": null, \"terminated_at\": null}"
        log_message "VM $vmid description updated to default json format"
    else
        log_message "Updating VM $vmid description format"
        pvesh set /nodes/$node_hostname/qemu/$vmid/config --description "{\"template\": \"$description\", \"terminated_at\": null}"
        log_message "VM $vmid description updated to json format"
    fi

    ((updated_vms_count++))
    sleep 10s
done

log_message "Successfully update description of $updated_vms_count VM with json format"