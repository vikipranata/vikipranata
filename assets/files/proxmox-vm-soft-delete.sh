#!/bin/bash
log_message() {
  local message=$1
  local timestamp=$(TZ='Asia/Jakarta' date +"%Y-%m-%dT%H:%M:%S%:z")
  echo "$timestamp - \"$message\"" | tee -a /var/log/pve/lite-soft-delete.log
}

# Initialize variables
netboxToken="fill_netbox_token"
netboxEndpoint="fill_netbox_url"
target_hours=75

# Initialize temporary files for counters
echo 0 > /tmp/count_deleted_rrdcache
echo 0 > /tmp/count_deleted_vms
echo 0 > /tmp/count_deleted_vmip
echo 0 > /tmp/failed_count_deleted_rrdcache
echo 0 > /tmp/failed_count_deleted_vms
echo 0 > /tmp/failed_count_deleted_vmip

# Get vmid with node locations then iterate
pvesh get /pools/TERMINATED --output-format json | jq -r '.members[] | "\(.vmid) \(.node)"' | while read vmid node; do
    description=$(pvesh get /nodes/$node/qemu/$vmid/config --output-format json | jq -r .description | jq -r .terminated_at)
    # Check that the description exists and matches the expected format, including the time zone, e.g. 2025-03-21T01:12:05+07:00
    if [[ $description =~ ([0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}\+[0-9]{2}:[0-9]{2}) ]]; then
        # Extract the date with timezone from the description using regex
        terminated_date="${BASH_REMATCH[1]}"

        # Convert the terminated date to a Unix timestamp and calculate the difference
        terminated_timestamp=$(date -d "$terminated_date" +%s)
        current_timestamp=$(date +%s)
        diff_hours=$(( (current_timestamp - terminated_timestamp) / 3600 ))

        if (( diff_hours > $target_hours )); then
            log_message "VM $vmid is older than $target_hours hours. Deleting RRD data, VM and Releasing IP"

            # Clean up rrd data from vmid in all node
            if ls /var/lib/rrdcached/db/pve2-vm/$vmid > /dev/null 2>&1; then
                rm -rf /var/lib/rrdcached/db/pve2-vm/$vmid
                log_message "RRD data for VM $vmid on node $node has been deleted"
                echo $(( $(cat /tmp/count_deleted_rrdcache) + 1 )) > /tmp/count_deleted_rrdcache
            else
                log_message "RRD data for VM $vmid on node $node does not exist or could not be deleted, please check again later"
                echo $(( $(cat /tmp/failed_count_deleted_rrdcache) + 1 )) > /tmp/failed_count_deleted_rrdcache
            fi

            # Delete VM and release IP address in current host only
            vmid_lists=$(pvesh get /nodes/$(hostname -s)/qemu --output-format json | jq -r .[].vmid)
            if echo "$vmid_lists" | grep -q $vmid; then

                # Release IP address on Netbox
                vmid_ip=$(pvesh get /nodes/$node/qemu/$vmid/config --output-format json | jq -r .ipconfig0 | sed 's/ip=//')
                if [[ -n "$vmid_ip" ]]; then
                    ipam_id=$(curl -ks --header "Authorization: token $netboxToken" -X GET $netboxEndpoint/api/ipam/ip-addresses/?q=$vmid_ip | jq -r '.results[0].id')
                    if [ "$?" -ne 0 ]; then
                        log_message "Curl: Error retrieve data from netbox for vmid $vmid in node $node";
                        echo $(( $(cat /tmp/failed_count_deleted_vmip) + 1 )) > /tmp/failed_count_deleted_vmip
                    else
                        log_message "VM $vmid ipconfig0 IP address $vmid_ip with id $ipam_id, releasing IP address"
                        curl -ks --header "Authorization: token $netboxToken" -X DELETE $netboxEndpoint/api/ipam/ip-addresses/$ipam_id/
                        if [ "$?" -ne 0 ]; then
                            log_message "Curl: Error retrieve data from netbox for vmid $vmid in node $node";
                            echo $(( $(cat /tmp/failed_count_deleted_vmip) + 1 )) > /tmp/failed_count_deleted_vmip
                        else
                            echo $(( $(cat /tmp/count_deleted_vmip) + 1 )) > /tmp/count_deleted_vmip
                            log_message "IP address $vmid_ip with id $ipam_id has been released"
                        fi
                    fi
                else
                    log_message "VM $vmid ipconfig0 value not found, please check again later"
                    echo $(( $(cat /tmp/failed_count_deleted_vmip) + 1 )) > /tmp/failed_count_deleted_vmip
                fi

                # Delete VM in current host only
                if pvesh delete /nodes/$node/qemu/$vmid; then
                    log_message "VM $vmid was deleted on node $node has completed"
                    echo $(( $(cat /tmp/count_deleted_vms) + 1 )) > /tmp/count_deleted_vms
                else
                    log_message "VM $vmid could not be deleted on node $node, please check again later"
                    echo $(( $(cat /tmp/failed_count_deleted_vms) + 1 )) > /tmp/failed_count_deleted_vms
                fi
            else
                log_message "VM $vmid does not exist on node $node, skipping process"
            fi

            sleep 60s

        else
            echo "VM $vmid is not older than $target_hours hours, skipping process"
        fi
    else
        log_message "VM $vmid not found in $(hostname -s) or description not in the expected format"
    fi
done

# Final log message
log_message "Task clean up RRD data $(cat /tmp/count_deleted_rrdcache) success and $(cat /tmp/failed_count_deleted_rrdcache) failure"
log_message "Task delete VM in $(hostname -s) $(cat /tmp/count_deleted_vms) success and $(cat /tmp/failed_count_deleted_vms) failure"
log_message "Task release VM IP adderess $(cat /tmp/count_deleted_vmip) success and $(cat /tmp/failed_count_deleted_vmip) failure"
