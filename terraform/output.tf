output "aerospike_servers" {
    value = {
        for instance in aws_instance.aerospike_server:
        instance.availability_zone => "${instance.private_ip}"
    }
}

# Output the SSH command used to login to each EC2 instance
output "bastion_hosts" {
    value = {
        for instance in aws_instance.bastion_host:
        instance.availability_zone => "${instance.public_ip}"
    }
}
