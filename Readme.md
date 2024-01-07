# Deploying a k3s cluster to aws and automating it via makefile and shell script

## Prerequisites knowledge

- linux commands, shell script, makefile, aws-ec2

## Developer instructions

- To run the project  you must first install aws cli. type aws configure and setup aws cli for your machine
- After running the commands the terminal might request/prompt for your permission a couple of times
- To automate the infra(You must have aws cli configured) type:
    make automate

## Explanation of code base
Note that the project directory has a nginx folder which consists of nginx.conf and a dockerfile.
In the root you will find a .pem file that contains the public key to access the servers.
You will also see a makefile and a shell script that has all the functions to execute/automate the infrastructure.

Now, let's first discuss about what we want to achieve first. We primarily want to deploy a kubernetes cluster in baremetal and automate the deployment of cluster. There will be 3 nodes in the cluster:  
- Master node
- Worker node-1
- Worker node-2

There will be another node outside the cluster which will have nginx setup. The nginx will be responsible to perform subdomain routing and forward the traffic to their respective service. Each service will have a nodeport to access the pods.
The domains are:
- fr.poridhi.io
- api.poridhi.io

We will set this up in our local environment so that we can test it out from postman as well.

Let us now try to understand the code:

in the makefile we find the command automate. inside it executes the shell script named make-script.sh
Let's explore the script.

At the bottom of the script we find a main() function and the main getting executed. Inside the main method we see multiple functions sequentially getting executed. Let us see what they do in short:

- create_vpc: this method is responsible to create a vpc
- create_and_attach_igw: to send traffic inside the vpc we need to create and attach an igw to the vpc that we created.
- create_and_update_route_table: we will update the route table so that traffic can egress via the igw from inside the vpc
- create_public_subnet: We need a public subnet to deploy the cluster ec2 instances. This method creates the public subnet under the vpc that we created
- create_and_config_security_group_nodes: We must create and configure security group for the ec2 instance nodes so that we allow only traffic that are necessary. This method does that for us
- create_ec2_nodes: this method creates 3 nodes: master, worker-1,worker-2 and attaches the security group that we created.
- create_and_config_nginx_security_group: This method creates and configures security group for the instance
- create_nginx_node: This method creates the ec2 instance node for the nginx
- setup_kube_master: this method installs k3s inside master node
- get_master_token: we get the token of master via this method to connect master with the workers
- setup_kube_workers: We ensure that the kubernetes workers are properly confugured with their master. To do this, this method uses K3S_URL and K3S token that we just got
- deploy_pods: finally, this method ssh into master and pulls the required repo and deploys the pods to their servers
- setup_nginx_server: we want nginx to load balance the traffic to the pods
- update_run_nginx: this method writes/updates the nginx.conf file locally, then copies the folder nginx to our nginx-server and finally builds it in an image

And there, our automated deployment for a k3s cluster has been deployed and all done via makefile and shell script with just one command "make automate".