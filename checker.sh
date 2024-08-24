#!/bin/bash

# Define associative arrays mapping ASGs to their LBs
declare -A asg_lb_pairs=(
    ["ASG-01"]="LB-01"
    ["ASG-02"]="LB-02-A LB-02-B"
)

# Function to print the separator line
print_separator() {
    printf "====================================================\n"
}

# Function to get instance IDs for ASG
get_asg_instance_ids() {
    local asg_name="$1"
    aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names "$asg_name" --query "AutoScalingGroups[*].Instances[].InstanceId" --output text
}

# Function to get instance IDs for LB
get_lb_instance_ids() {
    local lb_name="$1"
    aws elb describe-instance-health --load-balancer-name "$lb_name" --query "InstanceStates[].InstanceId" --output text
}

# Function to get instance IP address
get_instance_ip() {
    local instance_id="$1"
    aws ec2 describe-instances --instance-ids "$instance_id" --query "Reservations[*].Instances[*].PrivateIpAddress" --output text
}

# Function to check if instance is present in supplied set of instance IDs
is_instance_in_set() {
    local instance_id="$1"
    local instance_ids="$2"
    [[ $instance_ids =~ (^|[[:space:]])"$instance_id"($|[[:space:]]) ]]
}

# Array to store mismatched pairs
mismatched_pairs=()

# Main script
for asg_name in "${!asg_lb_pairs[@]}"; do
    asg_instance_ids=$(get_asg_instance_ids "$asg_name")
    asg_count=$(echo "$asg_instance_ids" | wc -w)
    echo "Instance count for ASG $asg_name: $asg_count"

    lb_list=${asg_lb_pairs[$asg_name]}
    for lb_name in $lb_list; do
        lb_instance_ids=$(get_lb_instance_ids "$lb_name")
        lb_count=$(echo "$lb_instance_ids" | wc -w)
        echo "Instance count for LB $lb_name: $lb_count"

        if [ "$asg_count" -ne "$lb_count" ]; then
            mismatched_pairs+=("$asg_name" "$asg_instance_ids" "$lb_name" "$lb_instance_ids")
            echo "Instance counts are not equal for ASG $asg_name and LB $lb_name."
        else
            echo "Instance counts are equal for ASG $asg_name and LB $lb_name."
        fi
    done
done

# If mismatched pairs are found
if [ ${#mismatched_pairs[@]} -gt 0 ]; then
    print_separator
    printf "***************** MISMATCHED PAIRS *****************\n"
    print_separator

    # Print mismatched pairs and find IP addresses not present in either ASG or LB
    for ((i=0; i<${#mismatched_pairs[@]}; i+=4)); do
        printf "ASG_NAME: %s\n" "${mismatched_pairs[i]}"
        printf "ASG_COUNT: %s\n" "$(echo "${mismatched_pairs[i+1]}" | wc -w)"
        printf "LB_NAME: %s\n" "${mismatched_pairs[i+2]}"
        printf "LB_COUNT: %s\n" "$(echo "${mismatched_pairs[i+3]}" | wc -w)"

        asg_instance_ids="${mismatched_pairs[i+1]}"
        lb_instance_ids="${mismatched_pairs[i+3]}"

        # Compare instance IDs and print IP addresses not present in either ASG or LB
        for instance_id in $asg_instance_ids; do
            if ! is_instance_in_set "$instance_id" "$lb_instance_ids"; then
                instance_ip=$(get_instance_ip "$instance_id")
                printf "Instance ID: %s, IP Address: %s (Not in LB)\n" "$instance_id" "$instance_ip"
            fi
        done
        for instance_id in $lb_instance_ids; do
            if ! is_instance_in_set "$instance_id" "$asg_instance_ids"; then
                instance_ip=$(get_instance_ip "$instance_id")
                printf "Instance ID: %s, IP Address: %s (Not in ASG)\n" "$instance_id" "$instance_ip"
            fi
        done

    done
    print_separator
    exit 1
# In case of success
else
  print_separator
  echo "No mismatched pairs found"
  print_separator
fi
