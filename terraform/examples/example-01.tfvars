# ------------------------------------------------------------------------------
#  Aerospike on AWS - Example 1
# ------------------------------------------------------------------------------
#  A 2-node Aerospike cluster spanning 2 AZs. The m5d instance has a 75GB
#  Instance Store Volume.
# ------------------------------------------------------------------------------

project_name = "Aerospike Example 1"

region = "us-west-2"

availability_zones = ["us-west-2a","us-west-2b"]

aerospike_cluster_size = 2

aerospike_instance_type = "m5d.large"

aerospike_shadow_devices = {
    "count" = 0
}
