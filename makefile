AWS_REGION := us-east-1
INSTANCE_TYPE := t2.micro
AMI_ID := ami-0c7217cdde317cfec  # Replace with your desired AMI ID
KEY_NAME := aws_login_1  # Replace with your key pair name

VPC_NAME := test vpc
VPC_CIDR := 10.0.0.0/16
VPC_ID := vpc-03427942ac95ed851

PUBLIC_SUBNET_NAME := subnet-pub
PUBLIC_SUBNET_CIDR := 10.0.1.0/24
PUBLIC_SUBNET_ID := subnet-000b3d1e4e2589db0

IGW_NAME := test-igw
IGW_ID := igw-0bcaa65f80c06ea98

ROUTE_TABLE_NAME := test-route-table
ROUTE_TABLE_ID := rtb-019826fa73feb6003
ROUTE_TABLE_DESTINATION := 0.0.0.0/0


AVAILABILITY_ZONE := 


## Instances


# create-vpc-command := $(shell aws ec2 create-vpc --cidr-block $(VPC_CIDR) --region $(AWS_REGION) --query 'Vpc.{VpcId:VpcId}' --output text --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=$(VPC_NAME)}]')
# create-igw-command := $(shell aws ec2 create-internet-gateway --region $(AWS_REGION) --query 'InternetGateway.{InternetGatewayId:InternetGatewayId}' --output text)

create-vpc:
	@ aws ec2 create-vpc --cidr-block $(VPC_CIDR) --region $(AWS_REGION) --query 'Vpc.{VpcId:VpcId}' --output text --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=$(VPC_NAME)}]'
create-igw:
	@ aws ec2 create-internet-gateway --region $(AWS_REGION) --query 'InternetGateway.{InternetGatewayId:InternetGatewayId}' --output text
attach-igw:
	@ aws ec2 attach-internet-gateway --vpc-id $(VPC_ID) --internet-gateway-id $(IGW_ID) --region $(AWS_REGION)


create-route-table: 
	@ aws ec2 create-route-table --vpc-id your-vpc-id --region your-region --query 'RouteTable.{RouteTableId:RouteTableId}' --output text

update-route-table:
	@ aws ec2 create-route --route-table-id $(ROUTE_TABLE_ID) --destination-cidr-block $(ROUTE_TABLE_DESTINATION) --gateway-id $(IGW_ID) --region $(AWS_REGION)

create-public-subnet:
	@ aws ec2 create-subnet --vpc-id $(VPC_ID) --cidr-block $(PUBLIC_SUBNET_CIDR) --region $(AWS_REGION) --query 'Subnet.{SubnetId:SubnetId}' --output text --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=$(PUBLIC_SUBNET_NAME)}]' 

NODES_SECURITY_GROUP := test-instance-sg
SECURITY_GROUP_DESCRIPTION :='This is a security group only for the 3 instances'
NODES_SECURITY_GROUP_ID := sg-080aa510588914ad8

create-security-group:
	@ aws ec2 create-security-group --vpc-id $(VPC_ID) --group-name $(NODES_SECURITY_GROUP) --description $(SECURITY_GROUP_DESCRIPTION) --region $(AWS_REGION)
configure-security-group:
    # Set inbound rules for the security group
	@ aws ec2 authorize-security-group-ingress --group-id $(NODES_SECURITY_GROUP_ID) --protocol all --port -1 --cidr 0.0.0.0/0 --region $(AWS_REGION)
	# @ aws ec2 authorize-security-group-egress --group-id $(NODES_SECURITY_GROUP_ID) --protocol all --port -1 --cidr 0.0.0.0/0 --region $(AWS_REGION)
	# --protocol tcp --port 22 --cidr 0.0.0.0/24 
create-ec2-instance:
	@ aws ec2 run-instances --image-id $(AMI_ID) --count 3 --instance-type $(INSTANCE_TYPE) --key-name $(KEY_NAME) --subnet-id $(PUBLIC_SUBNET_ID) --security-group-ids $(NODES_SECURITY_GROUP_ID) --region $(AWS_REGION) --query 'Instances[0].InstanceId' --output text --associate-public-ip-address


setup-instance: ## Sets up nodejs version v20.10.0
	@ chmod +x ./scripts/setup-instance.sh
	@ ./scripts/setup-instance.sh

INSTANCE_ID_MASTER := i-043fe4f357370ce84
MASTER_PUBLIC_IP := 3.239.163.145
MASTER_PRIVATE_IP := 10.0.1.82
user := ubuntu
KEY_PAIR_FILE := ./aws_login_1.pem

set-kube-master:
	@ chmod 400 "aws_login_1.pem"
	@ ssh -i $(KEY_PAIR_FILE) $(user)@$(MASTER_PUBLIC_IP) 'sudo hostnamectl set-hostname kube-master && sudo apt update && sudo curl -sfL https://get.k3s.io | sh - && sudo apt update'

get-master-token:
	@ ssh -i $(KEY_PAIR_FILE) $(user)@$(MASTER_PUBLIC_IP) 'sudo cat /var/lib/rancher/k3s/server/node-token'

# NOTE: YOU MUST CREATE security group with ssh,http,https rules

WORKER_NODE_1_ID := i-03711095d713e119e
WORKER_NODE_1_PUBLIC_IP := 44.204.215.204
WORKER_NODE_1_PRIVATE_IP := 10.0.1.89

WORKER_NODE_2_ID := i-0909000848f8ed947
WORKER_NODE_2_PUBLIC_IP := 44.199.203.64
WORKER_NODE_2_PRIVATE_IP := 10.0.1.94

NGINX_ID := i-0cb666632f638023d	
NGINX_PUBLIC_IP := 3.82.26.91
NGINX_1_PRIVATE_IP := 10.0.1.135

K3S_URL := https://$(MASTER_PRIVATE_IP):6443
K3S_TOKEN := K10487a8c21a73530fa6406c50341173fac51ddea4939dcc94336ad506d6aafd73a::server:ba1765abe579ca3bb2d53f47caac6b67

set-workers:
	@ ssh -i $(KEY_PAIR_FILE) $(user)@$(WORKER_NODE_1_PUBLIC_IP) 'sudo hostnamectl set-hostname worker-1 && sudo apt update && sudo curl -sfL https://get.k3s.io | K3S_URL=$(K3S_URL) K3S_TOKEN=$(K3S_TOKEN) sh - && sudo apt update'
	@ ssh -i $(KEY_PAIR_FILE) $(user)@$(WORKER_NODE_2_PUBLIC_IP) 'sudo hostnamectl set-hostname worker-2 && sudo apt update && sudo curl -sfL https://get.k3s.io | K3S_URL=$(K3S_URL) K3S_TOKEN=$(K3S_TOKEN) sh - && sudo apt update'
check-svc:
	@ ssh -i $(KEY_PAIR_FILE) $(user)@$(MASTER_PUBLIC_IP) 'sudo kubectl get svc'
check-pods:
	@ ssh -i $(KEY_PAIR_FILE) $(user)@$(MASTER_PUBLIC_IP) 'sudo kubectl get pods -o wide'
check-nodes:
	@ ssh -i $(KEY_PAIR_FILE) $(user)@$(MASTER_PUBLIC_IP) 'sudo kubectl get nodes -A'

deploy-pods:
	@ ssh -i $(KEY_PAIR_FILE) $(user)@$(MASTER_PUBLIC_IP) 'sudo apt install git && git clone https://github.com/shajalahamedcse/fireops.git && cd fireops && cd svc1 && cd deployment && sudo kubectl apply -f deployment.yml'


NGINX_SECURITY_GROUP := nginx-sg
NGINX_SECURITY_GROUP_DESCRIPTION := 'Security group for nginx'
NGINX_SG_ID := sg-04d15e93971abe315
NGINX_NAME := 'nginx'
create-nginx-sg:
	@ aws ec2 create-security-group --vpc-id $(VPC_ID) --group-name $(NGINX_SECURITY_GROUP) --description $(NGINX_SECURITY_GROUP_DESCRIPTION) --region $(AWS_REGION)
configure-nginx-sg:
    # Set inbound rules for the security group
	@ aws ec2 authorize-security-group-ingress --group-id $(NGINX_SG_ID) --protocol all --port -1 --cidr 0.0.0.0/0 --region $(AWS_REGION)
	
	# @ aws ec2 authorize-security-group-egress --group-id $(NGINX_SG_ID) --protocol all --port -1 --cidr 0.0.0.0/0 --region $(AWS_REGION)
	# --protocol tcp --port 22 --cidr 0.0.0.0/24 

create-nginx-instance:
	@ aws ec2 run-instances --image-id $(AMI_ID) --count 1 --instance-type $(INSTANCE_TYPE) --key-name $(KEY_NAME) --subnet-id $(PUBLIC_SUBNET_ID) --security-group-ids $(NGINX_SG_ID)  --region $(AWS_REGION) --query 'Instances[0].InstanceId' --output text --associate-public-ip-address

NGINX_INSTANCE_ID := i-0c937835f489aa5fc
NGINX_PUBLIC_IP := 44.204.119.96
NGINX_PRIVATE_IP := 10.0.1.102

run-nginx:
	@ ssh -i $(KEY_PAIR_FILE) $(user)@$(NGINX_PUBLIC_IP) "sudo apt update -y && sudo apt install -y docker.io git && git clone https://github.com/Taif71/kube_make.git && cd kube_make && cd nginx && sudo docker build -t nginx . && sudo docker run -p 80:80 nginx"

##1. Create VPC, Subnet, IGW, Route Table, 
##2. Create 4 Instances under the same VPC
##3. Enter into each instance and change hostname
##4. Enter Into Master, install k3s, get the token
##5. Enter into 2 worker nodejs install k3s as worker, and set the token here
##6. Might need to restart the servers [DONT NEED THIS STEP]
##7. SSH into master and pull the code for fire ops then run the deployments 
##8. Enter into nginx server, install and configure nginx so that it can route traffic to worker nodes
##	 Deploy  2 services: api.poridhi.io   and   fr.poridhi.io
##8. Test and check it out