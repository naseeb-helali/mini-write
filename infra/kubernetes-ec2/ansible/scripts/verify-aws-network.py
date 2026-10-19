#!/usr/bin/env python3
"""Read-only verification of SG rules required by the Mini-Write K8s cluster."""
import ipaddress
import sys
import boto3

REGION = "us-east-1"
EXPECTED = {
    "control_plane": ("i-0552c82b27dd23b29", "10.20.10.206"),
    "worker_01": ("i-0512aeb1a30a22c4b", "10.20.10.230"),
    "worker_02": ("i-0ab5809e0a72e9cef", "10.20.11.245"),
}

ec2 = boto3.client("ec2", region_name=REGION)
response = ec2.describe_instances(InstanceIds=[value[0] for value in EXPECTED.values()])
instances = {}
for reservation in response["Reservations"]:
    for item in reservation["Instances"]:
        instances[item["InstanceId"]] = item

nodes = {}
all_group_ids = set()
for name, (instance_id, expected_ip) in EXPECTED.items():
    item = instances.get(instance_id)
    if not item:
        raise SystemExit(f"FAIL: instance not found: {instance_id}")
    actual_ip = item.get("PrivateIpAddress")
    if actual_ip != expected_ip:
        raise SystemExit(f"FAIL: {name} private IP {actual_ip!r} != expected {expected_ip}")
    group_ids = {group["GroupId"] for group in item.get("SecurityGroups", [])}
    if not group_ids:
        raise SystemExit(f"FAIL: {name} has no attached security groups")
    nodes[name] = {"ip": actual_ip, "groups": group_ids}
    all_group_ids.update(group_ids)

sg_response = ec2.describe_security_groups(GroupIds=sorted(all_group_ids))
groups = {group["GroupId"]: group for group in sg_response["SecurityGroups"]}


def port_allowed(rules, peer_group_ids, peer_ip, protocol, port):
    for rule in rules:
        rule_protocol = str(rule.get("IpProtocol", ""))
        protocol_numbers = {"tcp": "6", "udp": "17"}
        if rule_protocol not in ("-1", protocol, protocol_numbers[protocol]):
            continue
        if rule_protocol != "-1":
            low = rule.get("FromPort", port)
            high = rule.get("ToPort", port)
            if not (low <= port <= high):
                continue
        if any(pair.get("GroupId") in peer_group_ids for pair in rule.get("UserIdGroupPairs", [])):
            return True
        if peer_ip:
            address = ipaddress.ip_address(peer_ip)
            for item in rule.get("IpRanges", []):
                if address in ipaddress.ip_network(item["CidrIp"], strict=False):
                    return True
        if rule_protocol == "-1":
            return True
    return False


checks = []


def add_check(label, source_name, destination_name, protocol, port):
    source = nodes[source_name]
    destination = nodes[destination_name]
    ingress_ok = any(
        port_allowed(
            groups[group_id].get("IpPermissions", []),
            source["groups"], source["ip"], protocol, port,
        )
        for group_id in destination["groups"]
    )
    egress_ok = any(
        port_allowed(
            groups[group_id].get("IpPermissionsEgress", []),
            destination["groups"], destination["ip"], protocol, port,
        )
        for group_id in source["groups"]
    )
    checks.append((label, ingress_ok and egress_ok, ingress_ok, egress_ok))


add_check("Workers -> Control Plane TCP/6443 (worker_01)", "worker_01", "control_plane", "tcp", 6443)
add_check("Workers -> Control Plane TCP/6443 (worker_02)", "worker_02", "control_plane", "tcp", 6443)
add_check("Control Plane -> Worker 1 TCP/10250", "control_plane", "worker_01", "tcp", 10250)
add_check("Control Plane -> Worker 2 TCP/10250", "control_plane", "worker_02", "tcp", 10250)
for source_name in nodes:
    for destination_name in nodes:
        if source_name != destination_name:
            add_check(
                f"{source_name} -> {destination_name} UDP/4789 VXLAN",
                source_name, destination_name, "udp", 4789,
            )

print("Attached security groups:")
for name, node in nodes.items():
    print(f"  {name} ({node['ip']}): {', '.join(sorted(node['groups']))}")
print("\nRequired traffic checks:")
failed = False
for label, ok, ingress_ok, egress_ok in checks:
    print(f"  {'PASS' if ok else 'FAIL'} {label} [ingress={ingress_ok}, egress={egress_ok}]")
    failed |= not ok
if failed:
    print("\nOne or more required Security Group paths are missing. Do not run kubeadm init yet.")
    sys.exit(2)
print("\nAll required Security Group paths are allowed. This script does not inspect NACLs or route tables.")
