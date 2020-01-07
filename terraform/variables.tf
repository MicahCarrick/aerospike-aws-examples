# Project Name
# 
# A name for the project which will be used to create AWS 'Name' tags as well
# as a 'Project' tag.

variable "project_name" {
    type    = string
    default = "Aerospike Example"
}

# Key Name
# 
# A name of an EC2 Key Pair already available in the region.
#
# See: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html

variable "key_name" {
    type    = string
    default = null
}

# Region
#
# AWS Region in which to provision all infrastructure.

variable "region" {
    type    = string
    default = "us-west-2"
}

# Availability Zones
#
# A list of availability zones in which to provision instances for Aerospike
# Server nodes. A public/private subnet, NAT, and instances will be provisioned
# in each AZ.

variable "availability_zones" {
    type    = list
    default = ["us-west-2a", "us-west-2b"]
}

# NAT Type
#
# The type of NAT the Aerospike Server instances in the private subnet will use
# to connect out to the internet (such as to fetch software updates).
# 
#   'gateway'  - Use AWS NAT Gateway service 
#
#   'instance' - Use AWS NAT EC2 instance per AZ
#
#   'none'     - Private subnet will have no routes to the internet
#
# See: https://docs.aws.amazon.com/vpc/latest/userguide/vpc-nat-gateway.html
# See: https://docs.aws.amazon.com/vpc/latest/userguide/VPC_NAT_Instance.html

variable "nat_type" {
    type    = "string"
    default = "gateway"
}

# NAT Instance Type
#
# The EC2 instance type to use for the NAT instances if 'nat_type' = 'instance'.
#
# See: https://docs.aws.amazon.com/vpc/latest/userguide/VPC_NAT_Instance.html

variable "nat_instance_type" {
    type    = "string"
    default = "t2.micro"
}

# Aerospike Cluster Size
#
# The number of nodes in the Aerospike cluster. One EC2 instance will be created
# for each node and spread across AZs.

variable "aerospike_cluster_size" {
    type    = number
    default = 2
}

# Aerospike Instance Type
#
# The EC2 instance type to use for Aerospike nodes. Typically these are instance
# types which have SSD Instance Store Volumes such as the m5d, r5d, c5d, i3, and
# i3en instance families.

variable "aerospike_instance_type" {
    type    = string
    default = "m5d.large"
}

# Aerospike Shadow Devices
#
# A map describing the number, type and size of EBS Shadow Devices to attach to
# each Aerospike instance. Note that there are a number of factors that
# determine EBS IOPs/throughput including the volume size, instance type, EBS
# volume type, and credits.
#
# See: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/EBSVolumeTypes.html

variable "aerospike_shadow_devices" {
    type    = map
    default = {
        "count" = 0
        "type" = "gp2"
        "size" = 75
    }
}

# Aerospike Shadow Device Names
#
# A list of device names for EBS Shadow Devices which begin at /ddev/sdj to
# avoid conflict with possible device names used by Instance Store volumes.
# See: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/device_naming.html
variable "aerospioke_shadow_device_names" {
    type    = list
    default = [
        "/dev/sdj",
        "/dev/sdk",
        "/dev/sdl",
        "/dev/sdm",
        "/dev/sdn",
        "/dev/sdo",
        "/dev/sdp",
        "/dev/sdq",
        "/dev/sdr",
        "/dev/sds",
        "/dev/sdt",
        "/dev/sdu",
        "/dev/sdv",
        "/dev/sdw",
        "/dev/sdx",
        "/dev/sdy"
    ]
}

variable "vpc_cidr" {
    type    = string
    default = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
    type    = list
    default = ["10.0.128.0/20","10.0.144.0/20","10.0.160.0/20","10.0.176.0/20"]
}

variable "private_subnet_cidr" {
    type    = list
    default = ["10.0.0.0/19","10.0.32.0/19","10.0.64.0/19","10.0.96.0/19"]
}

variable "bastion_instance_type" {
    type    = string
    default = "t2.micro"
}

variable "bastion_ssh_ingress_cidrs" {
    type    = list
    default = ["0.0.0.0/0"]
}