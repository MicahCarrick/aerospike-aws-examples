
resource "aws_vpc" "main" {
    cidr_block            = "${var.vpc_cidr}"
    enable_dns_hostnames  = true

    tags = {
        Name = "${var.project_name} VPC"
        Project = "${var.project_name}"
    }
}

resource "aws_internet_gateway" "main" {
    vpc_id = "${aws_vpc.main.id}"

    tags = {
        Name = "${var.project_name} Gateway"
        Project = "${var.project_name}"
    }
}

resource "aws_eip" "nat" {
    count = "${length(var.availability_zones)}"
    vpc   = true

    tags = {
        Name = "${var.project_name} NAT IP"
        Project = "${var.project_name}"
    }
  
    depends_on = ["aws_internet_gateway.main"]
}

resource "aws_nat_gateway" "main" {
    count         = "${var.nat_type}" == "gateway" ? "${length(var.availability_zones)}" : 0
    allocation_id = "${aws_eip.nat[count.index].id}"
    subnet_id     = "${aws_subnet.public[count.index].id}"

    tags = {
        Name = "${var.project_name} NAT"
        Project = "${var.project_name}"
    }

    depends_on = ["aws_internet_gateway.main"]
}

# Most recent Amazon Linux 2 VPC NAT AMI
data "aws_ami" "amazon_nat_instance_image" {
    most_recent = true
    owners      = ["amazon"]

    filter {
        name   = "name"
        values = ["amzn-ami-vpc-nat*"]
    }
}

resource "aws_instance" "nat_instance" {
    count                  = "${var.nat_type}" == "instance" ? "${length(var.availability_zones)}" : 0
    instance_type          = "${var.nat_instance_type}"
    ami                    = "${data.aws_ami.amazon_nat_instance_image.id}"
    vpc_security_group_ids = ["${aws_security_group.nat_instance.id}"]
    subnet_id              = "${element(aws_subnet.public.*.id, count.index)}"
    key_name               = "${var.key_name}"
    source_dest_check      = false

    tags = {
        Name = "${var.project_name} NAT Instance"
        Project = "${var.project_name}"
    }

    depends_on = ["aws_eip.nat"]
}

resource "aws_eip_association" "nat_instance_eip" {
    count         = "${var.nat_type}" == "instance" ? "${length(var.availability_zones)}" : 0
    instance_id   = "${aws_instance.nat_instance[count.index].id}"
    allocation_id = "${aws_eip.nat[count.index].id}"

    depends_on = ["aws_instance.nat_instance", "aws_eip.nat"]
}

resource "aws_security_group" "nat_instance" {
    name              = "nat_instance"
    description       = "SG for NAT instances"
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

    # allow incoming ICMP "pings"
    ingress {
        from_port   = 8
        to_port     = 0
        protocol    = "icmp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    # allow incoming HTTP connections from private subnet
    ingress {
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = "${var.private_subnet_cidr}"
    }

    # allow incoming HTTPS connections from private subnet
    ingress {
        from_port   = 443
        to_port     = 443
        protocol    = "tcp"
        cidr_blocks = "${var.private_subnet_cidr}"
    }

    # allow incoming SSH connections from jump boxes
    ingress {
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = "${formatlist("%s/32", aws_instance.bastion_host.*.private_ip)}"
    }

    tags = {
        Name = "${var.project_name} NAT Instance SG"
        Project = "${var.project_name}"
    }
}

resource "aws_default_route_table" "default" {
    default_route_table_id = "${aws_vpc.main.default_route_table_id}"

    # No routes in default route table

    tags = {
        Name = "${var.project_name} Default Route Table"
        Project = "${var.project_name}"
    }
}

# Public subnet
resource "aws_subnet" "public" {
    count                   = "${length(var.availability_zones)}"
    vpc_id                  = "${aws_vpc.main.id}"
    cidr_block              = "${var.public_subnet_cidr[count.index]}"
    availability_zone       = "${var.availability_zones[count.index]}"
    map_public_ip_on_launch = true

    tags = {
        Name = "${var.project_name} Public Subnet"
        Project = "${var.project_name}"
    }
}

resource "aws_route_table" "public" {
    vpc_id = "${aws_vpc.main.id}"

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = "${aws_internet_gateway.main.id}"
    }

    tags = {
        Name = "${var.project_name} Public Route Table"
        Project = "${var.project_name}"
    }
}

resource "aws_route_table_association" "public" {
    count          = "${length(aws_subnet.public)}"
    subnet_id      = "${aws_subnet.public[count.index].id}"
    route_table_id = "${aws_route_table.public.id}"
}

# Private subnet
resource "aws_subnet" "private" {
    count                   = "${length(var.availability_zones)}"
    vpc_id                  = "${aws_vpc.main.id}"
    cidr_block              = "${var.private_subnet_cidr[count.index]}"
    availability_zone       = "${var.availability_zones[count.index]}"
    map_public_ip_on_launch = true

    tags = {
        Name = "${var.project_name} Private Subnet"
        Project = "${var.project_name}"
    }
}

resource "aws_route_table" "private" {
    count  = "${length(aws_subnet.private)}"
    vpc_id = "${aws_vpc.main.id}"

    # Adds a route to NAT Gateway if 'nat_type' = "gateway"
    dynamic "route" {
        for_each = var.nat_type == "gateway" ? [1] : []
        content {
            cidr_block = "0.0.0.0/0"
            nat_gateway_id = "${aws_nat_gateway.main[count.index].id}" 
        }
    }

    # Adds a route to NAT Instance if 'nat_type' = "instance"
    dynamic "route" {
        for_each = var.nat_type == "instance" ? [1] : []
        content {
            cidr_block = "0.0.0.0/0"
            instance_id = "${aws_instance.nat_instance[count.index].id}" 
        }
    }

    tags = {
        Name = "${var.project_name} Private Route Table"
        Project = "${var.project_name}"
    }
}

resource "aws_route_table_association" "private" {
    count          = "${length(aws_subnet.private)}"
    subnet_id      = "${aws_subnet.private[count.index].id}"
    route_table_id = "${aws_route_table.private[count.index].id}"
}

resource "aws_security_group" "bastion_host" {
    name              = "bastion_host"
    description       = "SG for Bastion Host instances"
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

    # allow outgoing SSH connections to private subnet
    egress {
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = "${var.private_subnet_cidr}"
    }

    # allow incoming SSH connections from CIDR defined in vars (default all)
    ingress {
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = "${var.bastion_ssh_ingress_cidrs}"
    }

    tags = {
        Name = "${var.project_name} Bastion Host SG"
        Project = "${var.project_name}"
    }
}

resource "aws_instance" "bastion_host" {
    count                  = "${length(var.availability_zones)}"
    instance_type          = "${var.bastion_instance_type}"
    ami                    = "${data.aws_ami.amazon_linux2_image.id}"
    vpc_security_group_ids = ["${aws_security_group.bastion_host.id}"]
    subnet_id              = "${element(aws_subnet.public.*.id, count.index)}"
    key_name               = "${var.key_name}"

    tags = {
        Name = "${var.project_name} Bastion"
        Project = "${var.project_name}"
    }

    depends_on = ["aws_nat_gateway.main"]
}