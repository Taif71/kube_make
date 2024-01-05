#!/bin/sh

# Set your variables here
# ...
AWS_REGION=us-east-1
VPC_NAME='poridhi vpc'
VPC_CIDR='10.0.0.0/16'
VPC_ID=""


create_vpc() {
    VPC_OUTPUT=$(aws ec2 create-vpc --cidr-block "$VPC_CIDR" --region "$AWS_REGION" --query 'Vpc.{VpcId:VpcId}' --output text --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value='$VPC_NAME'}]")
    # Store the VPC ID by removing trailing whitespace or newline characters
    VPC_ID=$(echo "$VPC_OUTPUT" | tr -d '\r\n')
}

IGW_NAME="poridhi-igw"
IGW_ID=""

create_and_attach_igw() {
    IGW_OUTPUT=$(aws ec2 create-internet-gateway --region "$AWS_REGION" --query 'InternetGateway.{InternetGatewayId:InternetGatewayId}' --output text --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value='$IGW_NAME'}]")
    # Store the VPC ID by removing trailing whitespace or newline characters
    IGW_ID=$(echo "$IGW_OUTPUT" | tr -d '\r\n')
    aws ec2 attach-internet-gateway --vpc-id "$VPC_ID" --internet-gateway-id "$IGW_ID" --region "$AWS_REGION"
}

ROUTE_TABLE_ID=""
ROUTE_TABLE_DESTINATION="0.0.0.0/0"
create_and_update_route_table() {
    ROUTE_TABLE_ID=$(aws ec2 describe-route-tables --region "$AWS_REGION" --filters Name=vpc-id,Values="$VPC_ID" --query 'RouteTables[0].RouteTableId' --output text)
    # ROUTE_TABLE_ID=$(aws ec2 create-route-table --vpc-id your-vpc-id --region your-region --query 'RouteTable.{RouteTableId:RouteTableId}' --output text)
    aws ec2 create-route --route-table-id "$ROUTE_TABLE_ID" --destination-cidr-block "$ROUTE_TABLE_DESTINATION" --gateway-id "$IGW_ID" --region "$AWS_REGION"
}

PUBLIC_SUBNET_NAME=poridhi-pub-subnet
PUBLIC_SUBNET_CIDR="10.0.1.0/24"
PUBLIC_SUBNET_ID=""
create_public_subnet() {
    PUBLIC_SUBNET_ID=$(aws ec2 create-subnet --vpc-id "$VPC_ID" --cidr-block "$PUBLIC_SUBNET_CIDR" --region "$AWS_REGION" --query 'Subnet.{SubnetId:SubnetId}' --output text --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value='$PUBLIC_SUBNET_NAME'}]')
}


NODES_SECURITY_GROUP_NAME=node-instances-sg
SECURITY_GROUP_DESCRIPTION='This is a security group only for the 3 instances'
NODES_SECURITY_GROUP_ID=""
NODES_SECURITY_GROUP_CIDR="0.0.0.0/0"
create_and_config_security_group_nodes() {
    aws ec2 create-security-group --vpc-id "$VPC_ID" --group-name "$NODES_SECURITY_GROUP_NAME" --description "$SECURITY_GROUP_DESCRIPTION" --region "$AWS_REGION" 
    SG_RESPONSE=$(aws ec2 describe-security-groups --region "$AWS_REGION" --filters Name=group-name,Values="$NODES_SECURITY_GROUP_NAME" Name=vpc-id,Values="$VPC_ID")
    NODES_SECURITY_GROUP_ID=$(echo "$SG_RESPONSE" | grep -o '"GroupId": *"[^"]*' | awk -F'"' '{print $4}')
    aws ec2 authorize-security-group-ingress --group-id "$NODES_SECURITY_GROUP_ID" --protocol all --port -1 --cidr "0.0.0.0/0" --region "$AWS_REGION"
}


INSTANCE_TYPE=t2.micro
AMI_ID=ami-0c7217cdde317cfec  # Replace with your desired AMI ID
KEY_NAME=aws_login_1  # Replace with your key pair name

MASTER_NODE_INSTANCE_ID=''
MASTER_NODE_INSTANCE_NAME='master'
MASTER_NODE_INSTANCE_PUBLIC_IP=""
MASTER_NODE_INSTANCE_PRIVATE_IP=""
USER=ubuntu

WORKER_NODE_1_INSTANCE_ID=''
WORER_NODE_1_INSTANCE_NAME='worker-1'
WORKER_NODE_1_PUBLIC_IP=""
WORKER_NODE_1_PRIVATE_IP=""

WORKER_NODE_2_INSTANCE_ID=''
WORER_NODE_2_INSTANCE_NAME='worker-2'
WORKER_NODE_2_PUBLIC_IP=""
WORKER_NODE_2_PRIVATE_IP=""

create_ec2_nodes() {
    MASTER_NODE_INSTANCE=$(aws ec2 run-instances --image-id "$AMI_ID" --count 1 --instance-type "$INSTANCE_TYPE" --key-name "$KEY_NAME" --subnet-id "$PUBLIC_SUBNET_ID" --security-group-ids "$NODES_SECURITY_GROUP_ID" --region "$AWS_REGION" --query 'Instances[0]' --output json --associate-public-ip-address --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$MASTER_NODE_INSTANCE_NAME}]")
    WORKER_NODE_1_INSTANCE=$(aws ec2 run-instances --image-id "$AMI_ID" --count 1 --instance-type "$INSTANCE_TYPE" --key-name "$KEY_NAME" --subnet-id "$PUBLIC_SUBNET_ID" --security-group-ids "$NODES_SECURITY_GROUP_ID" --region "$AWS_REGION" --query 'Instances[0]' --output json --associate-public-ip-address --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$WORER_NODE_1_INSTANCE_NAME}]")
    WORKER_NODE_2_INSTANCE=$(aws ec2 run-instances --image-id "$AMI_ID" --count 1 --instance-type "$INSTANCE_TYPE" --key-name "$KEY_NAME" --subnet-id "$PUBLIC_SUBNET_ID" --security-group-ids "$NODES_SECURITY_GROUP_ID" --region "$AWS_REGION" --query 'Instances[0]' --output json --associate-public-ip-address --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$WORER_NODE_2_INSTANCE_NAME}]")
    echo "Launched Master INSTANCE..."
    echo "Launched Worker1 INSTANCE...."
    echo "Launched Worker2 INSTANCE....."
    echo "Nodes are initializing....."
   
    MASTER_NODE_INSTANCE_ID=$(echo "$MASTER_NODE_INSTANCE" | grep -o '"InstanceId": *"[^"]*' | awk -F'"' '{print $4}')
    MASTER_NODE_INSTANCE_PRIVATE_IP=$(echo "$MASTER_NODE_INSTANCE" | grep -o '"PrivateIpAddress": *"[^"]*' | awk -F'"' '{print $4}')
    aws ec2 wait instance-running --instance-ids "$MASTER_NODE_INSTANCE_ID"
    MASTER_NODE_INSTANCE_PUBLIC_IP=$(aws ec2 describe-instances --instance-ids "$MASTER_NODE_INSTANCE_ID" --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
  
    WORKER_NODE_1_INSTANCE_ID=$(echo "$WORKER_NODE_1_INSTANCE" | grep -o '"InstanceId": *"[^"]*' | awk -F'"' '{print $4}')
    WORKER_NODE_1_PRIVATE_IP=$(echo "$WORKER_NODE_1_INSTANCE" | grep -o '"PrivateIpAddress": *"[^"]*' | awk -F'"' '{print $4}')
    aws ec2 wait instance-running --instance-ids "$WORKER_NODE_1_INSTANCE_ID"
    WORKER_NODE_1_PUBLIC_IP=$(aws ec2 describe-instances --instance-ids "$WORKER_NODE_1_INSTANCE_ID" --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)

  
    WORKER_NODE_2_INSTANCE_ID=$(echo "$WORKER_NODE_2_INSTANCE" | grep -o '"InstanceId": *"[^"]*' | awk -F'"' '{print $4}')
    WORKER_NODE_2_PRIVATE_IP=$(echo "$WORKER_NODE_2_INSTANCE" | grep -o '"PrivateIpAddress": *"[^"]*' | awk -F'"' '{print $4}')
    aws ec2 wait instance-running --instance-ids "$WORKER_NODE_2_INSTANCE_ID"
    WORKER_NODE_2_PUBLIC_IP=$(aws ec2 describe-instances --instance-ids "$WORKER_NODE_2_INSTANCE_ID" --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)

    echo "Master instance ID: $MASTER_NODE_INSTANCE_ID"
    echo "Master public IP: $MASTER_NODE_INSTANCE_PUBLIC_IP"
    echo "Master private IP: $MASTER_NODE_INSTANCE_PRIVATE_IP"

    echo "Worker-1 node instance ID: $WORKER_NODE_1_INSTANCE_ID"
    echo "Worker-1 node public IP: $WORKER_NODE_1_PUBLIC_IP"
    echo "Worker-1 private IP: $MASTER_NODE_INSTANCE_PRIVATE_IP"

    echo "Worker-2 node instance ID: $WORKER_NODE_2_INSTANCE_ID"
    echo "Worker-2 node public IP: $WORKER_NODE_2_PUBLIC_IP"
    echo "Worker-2 private IP: $MASTER_NODE_INSTANCE_PRIVATE_IP"
}


NGINX_SECURITY_GROUP_NAME=nginx-security-group
NGINX_SECURITY_GROUP_DESCRIPTION='Security group for nginx'
NGINX_SECURITY_GROUP_ID=""
create_and_config_nginx_security_group() {
    aws ec2 create-security-group --vpc-id "$VPC_ID" --group-name "$NGINX_SECURITY_GROUP_NAME" --description "$SECURITY_GROUP_DESCRIPTION" --region "$AWS_REGION" 
    SG_RESPONSE=$(aws ec2 describe-security-groups --region "$AWS_REGION" --filters Name=group-name,Values="$NGINX_SECURITY_GROUP_NAME" Name=vpc-id,Values="$VPC_ID")
    NGINX_SECURITY_GROUP_ID=$(echo "$SG_RESPONSE" | grep -o '"GroupId": *"[^"]*' | awk -F'"' '{print $4}')
    aws ec2 authorize-security-group-ingress --group-id "$NGINX_SECURITY_GROUP_ID" --protocol all --port -1 --cidr "0.0.0.0/0" --region "$AWS_REGION"
}

NGINX_INSTANCE_NAME="nginx"
NGINX_INSTANCE_ID=""
NGINX_INSTANCE_PUBLIC_IP=""
NGINX_INSTANCE_PRIVATE_IP=""
create_nginx_node() {
    echo "Launched nginx INSTANCE."
    echo "NGINX is initializing....."
    NGINX_INSTANCE=$(aws ec2 run-instances --image-id "$AMI_ID" --count 1 --instance-type "$INSTANCE_TYPE" --key-name "$KEY_NAME" --subnet-id "$PUBLIC_SUBNET_ID" --security-group-ids "$NGINX_SECURITY_GROUP_ID" --region "$AWS_REGION" --query 'Instances[0]' --output json --associate-public-ip-address --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$NGINX_INSTANCE_NAME}]")
    NGINX_INSTANCE_ID=$(echo "$NGINX_INSTANCE" | grep -o '"InstanceId": *"[^"]*' | awk -F'"' '{print $4}')
    NGINX_INSTANCE_PRIVATE_IP=$(echo "$NGINX_INSTANCE" | grep -o '"PrivateIpAddress": *"[^"]*' | awk -F'"' '{print $4}')
    aws ec2 wait instance-running --instance-ids "$NGINX_INSTANCE_ID"
    NGINX_INSTANCE_PUBLIC_IP=$(aws ec2 describe-instances --instance-ids "$NGINX_INSTANCE_ID" --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)

    echo "NGINX instance ID: $NGINX_INSTANCE_ID"
    echo "NGINX public IP: $NGINX_INSTANCE_PUBLIC_IP"
    echo "NGINX private IP: $NGINX_INSTANCE_PRIVATE_IP"
}

KEY_PAIR_FILE='./aws_login_1.pem'
setup_kube_master() {
    chmod 400 "$KEY_PAIR_FILE"
    ssh -i "$KEY_PAIR_FILE" "$USER@$MASTER_NODE_INSTANCE_PUBLIC_IP" 'sudo hostnamectl set-hostname kube-master && sudo apt update && sudo curl -sfL https://get.k3s.io | sh - && sudo apt update'
}

K3S_URL="https://$MASTER_NODE_INSTANCE_PRIVATE_IP:6443"
K3S_TOKEN=""

get_master_token() {
    K3S_TOKEN=$(ssh -i "$KEY_PAIR_FILE" "$user@$MASTER_NODE_INSTANCE_PUBLIC_IP" 'sudo cat /var/lib/rancher/k3s/server/node-token')
    echo "K3S URL: $K3S_URL"
    echo "K3S Token: $K3S_TOKEN"
}

setup_kube_workers() {
    ssh -i "$KEY_PAIR_FILE" "$USER@$WORKER_NODE_1_PUBLIC_IP" "sudo hostnamectl set-hostname worker-1 && sudo apt update && sudo curl -sfL https://get.k3s.io | K3S_URL=$K3S_URL K3S_TOKEN=$K3S_TOKEN sh - && sudo apt update"
	ssh -i "$KEY_PAIR_FILE" "$USER@$WORKER_NODE_2_PUBLIC_IP" "sudo hostnamectl set-hostname worker-2 && sudo apt update && sudo curl -sfL https://get.k3s.io | K3S_URL=$K3S_URL K3S_TOKEN=$K3S_TOKEN sh - && sudo apt update"
}

deploy_pods() {
    ssh -i "$KEY_PAIR_FILE" "$USER@$MASTER_NODE_INSTANCE_PUBLIC_IP" 'sudo apt install git && git clone https://github.com/shajalahamedcse/fireops.git && cd fireops && cd svc1 && cd deployment && sudo kubectl apply -f deployment.yml'
}

run_nginx_server() {
    ssh -i "$KEY_PAIR_FILE" "$user@$NGINX_PUBLIC_IP" 'sudo apt update -y && sudo apt install -y docker.io git && git clone https://github.com/Taif71/kube_make.git && cd kube_make && cd nginx && sudo docker build -t nginx . && sudo docker run -p 80:80 nginx'
}

# Other functions for creating resources (IGW, Route Table, Security Groups, etc.)


# detach-delete-igw:


# Deployment Steps
main() {
    # Execute the functions in sequence
    create_vpc
    create_and_attach_igw
    create_and_update_route_table
    create_public_subnet
    create_and_config_security_group_nodes
    create_ec2_nodes
    create_and_config_nginx_security_group
    create_nginx_node
    setup_kube_master
    get_master_token
    setup_kube_workers
    deploy_pods
    # run_nginx_server
}

# Run the deployment
main "$@"










#### DELETION OF PROVISION
#1. delete ec2
#2. delete security groups
#3. Detach IGW
#2. Delete IGW
#3. Delete VPC - Route table get auto deleted
#4. Delete subnet