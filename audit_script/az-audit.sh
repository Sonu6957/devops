#!/usr/bin/env bash

set -euo pipefail
RESOURCE_GROUP=""
OUTPUT_FILE="reports/audit-$(date +%Y%m%d-%H%M%S).json"

cleanup(){
	echo" Audit process completed"
}
trap cleanup EXIT

usage(){
	echo " Usage: $0 -g <resource-group>"
	exit 1
}

while getopts "g:h" opt; do
	case "${opt}" in
		g) RESOURCE_GROUP="${OPTARG}" ;;
		h|*) usage ;;
	esac
done

if [[ -z "{$RESOURCE_GROUP}" ]]; then
	echo "ERROR: Resource group flag is required."
	usage
fi



echo "Checking unassociated IPs"
UNASSIGNED_IPs=$(az network public-ip list -g "${RESOURCE_GROUP}" --query "[?ipConfiguration==null].{Name:name, Location:location}" -o json)

echo "Checking unattached Disk"
UNATTACHED_DISK=$(az disk list -g "${RESOURCE_GROUP}" --query "[?managedBy==null].{Name:name, SizeGB:diskSizeGb}" -o json)

echo "Checking storage account for public Access"
PUBLIC_STORAGE=$(az storage account list -g "${RESOURCE_GROUP}" --query "[?allowedBlobPublicAccess==true].{Name:name, ResourceGroup:resourceGroup}" -o json)

mkdir -p reports
jq -n --arg rg "${RESOURCE_GROUP}" --argjson ips "${UNASSIGNED_IPs}" --argjson disks "${UNATTACHED_DISK}" --argjson storage "${PUBLIC_STORAGE}" \
	  '{
		targetResourceGroup: $rg,
		timestamp: (now | strftime("%Y-%m-%dT%H:%M:%SZ")),
		findings:{
			unassignedPublicIPs: $ips,
			unattachedDisks: $disks,
			insecureStorageAccounts:$storage
		}
	   }' > "${OUTPUT_FILE}"
echo "Audit Complete"
cat "${OUTPUT_FILE}" | jq .
