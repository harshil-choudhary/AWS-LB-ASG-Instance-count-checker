# Use
- This script checks if the instances launched by an ASG (Auto Scaling Group) and the instances behind the corresponding LBs (Load Balancers) are equal in count and the same.
- If the instance match, it prints "No mismatched pairs found"
- If the instances don't match or are not equal, It prints the mismatched pairs in the below format: -
```
ASG_NAME: AS-01
ASG_COUNT: 4
LB_NAME: AS-02
LB_COUNT: 5
Instance ID: i-xxxxxxxxxxx, IP Address: 10.xx.xx.xx (Not in ASG)
```

# Requirement
- AWS CLI needs to be setup for the account for which the script is intended to be run.
