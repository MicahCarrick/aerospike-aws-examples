# ------------------------------------------------------------------------------
#  Aerospike on AWS - Example 2
# ------------------------------------------------------------------------------
#  A 2-node Aerospike cluster spanning 2 AZs. The m5d instance has a 75GB SSD
#  Instance Store Volume for the primary device and a 75GB EBS volume attached
#  as a "shadow device" (backup).
# ------------------------------------------------------------------------------

project_name = "Aerospike Example 2"

region = "us-west-2"

availability_zones = ["us-west-2a","us-west-2b"]

aerospike_cluster_size = 2

aerospike_instance_type = "m5d.large"

aerospike_shadow_devices = {
    "count" = 1
    "type" = "gp2"
    "size" = 75
}
