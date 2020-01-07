
# Most recent Amazon Linux 2 AMI
data "aws_ami" "amazon_linux2_image" {
    most_recent = true
    owners      = ["amazon"]

    filter {
        name   = "name"
        values = ["amzn2-ami-hvm*"]
    }
}

resource "aws_instance" "aerospike_server" {
    count                       = "${var.aerospike_cluster_size}"
    instance_type               = "${var.aerospike_instance_type}"
    ami                         = "${data.aws_ami.amazon_linux2_image.id}"
    vpc_security_group_ids      = ["${aws_security_group.aerospike_node.id}"]
    associate_public_ip_address = false
    subnet_id                   = "${element(aws_subnet.private.*.id, count.index)}"
    key_name                    = "${var.key_name}"

    tags = {
        Name = "${var.project_name} Node"
        Project = "${var.project_name}"
    }

    #depends_on = ["aws_nat_gateway.main"]
}

resource "aws_ebs_volume" "aerospike_shadow_device" {
    count             = "${var.aerospike_cluster_size * var.aerospike_shadow_devices.count}"
    availability_zone = "${element(aws_subnet.private.*.availability_zone, floor(count.index / var.aerospike_shadow_devices.count))}"
    type              = "${var.aerospike_shadow_devices.type}"
    size              = "${var.aerospike_shadow_devices.size}"

    tags = {
        Name = "${var.project_name} Shadow Volume"
        Project = "${var.project_name}"
    }
}

resource "aws_volume_attachment" "aerospike_ebs_attachment" {
    count        = "${var.aerospike_cluster_size * var.aerospike_shadow_devices.count}"
    device_name  = "${element(slice(var.aerospioke_shadow_device_names, 0, var.aerospike_shadow_devices.count), count.index)}"
    instance_id  = "${aws_instance.aerospike_server[floor(count.index / var.aerospike_shadow_devices.count)].id}"
    volume_id    = "${aws_ebs_volume.aerospike_shadow_device[count.index].id}"
}

# Security group which allows SSH access to the instance, Aerospike fabric
# traffic from the private subnet, and Aerospike service traffic from both
# private and public subnets.
resource "aws_security_group" "aerospike_node" {
    name              = "aerospike_node"
    description       = "SG for Aerospiker Server nodes"
    vpc_id            = "${aws_vpc.main.id}"

    # allow outgoing ICMP "pings"
    egress {
        from_port   = 8
        to_port     = 0
        protocol    = "icmp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    # allow outgoing HTTP connections
    egress {
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    # allow outgoing HTTPS connections
    egress {
        from_port   = 443
        to_port     = 443
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    # allow incoming SSH connections from jump boxes
    ingress {
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = "${formatlist("%s/32", aws_instance.bastion_host.*.private_ip)}"
    }

    # allow incomming fabric connections from the private subnet only
    ingress {
        from_port   = 3001
        to_port     = 3001
        protocol    = "tcp"
        cidr_blocks = "${var.private_subnet_cidr}"
    }

    # allow incoming service connections from private or public subnets
    ingress {
        from_port   = 3000
        to_port     = 3000
        protocol    = "tcp"
        cidr_blocks = "${concat(var.public_subnet_cidr, var.private_subnet_cidr)}"
    }

    tags = {
        Name = "${var.project_name} Node SG"
        Project = "${var.project_name}"
    }

    depends_on = ["aws_instance.bastion_host"]
}