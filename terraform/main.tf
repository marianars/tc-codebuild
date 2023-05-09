# Definir el proveedor AWS
provider "aws" {
  region = "us-east-1" # Cambiar por la región que prefieras
}

# Crear la VPC
resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16" # Cambiar por el rango de direcciones IP que prefieras

  tags = {
    Name = "my-vpc"
  }
}

# Crear los Internet Gateway
resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "my-igw"
  }
}

# Crear las subredes públicas
resource "aws_subnet" "public_subnet_1" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.1.0/24" # Cambiar por el rango de direcciones IP que prefieras
  availability_zone = "us-east-1a"  # Cambiar por la zona de disponibilidad que prefieras

  tags = {
    Name = "public-subnet-1"
  }
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.2.0/24" # Cambiar por el rango de direcciones IP que prefieras
  availability_zone = "us-east-1b"  # Cambiar por la zona de disponibilidad que prefieras

  tags = {
    Name = "public-subnet-2"
  }
}

# Crear las subredes privadas
resource "aws_subnet" "private_subnet_1" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.3.0/24" # Cambiar por el rango de direcciones IP que prefieras
  availability_zone = "us-east-1a"  # Cambiar por la zona de disponibilidad que prefieras

  tags = {
    Name = "private-subnet-1"
  }
}

resource "aws_subnet" "private_subnet_2" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.4.0/24" # Cambiar por el rango de direcciones IP que prefieras
  availability_zone = "us-east-1b"  # Cambiar por la zona de disponibilidad que prefieras

  tags = {
    Name = "private-subnet-2"
  }
}

# Crear el NAT Gateway
resource "aws_nat_gateway" "my_nat_gateway" {
  allocation_id = aws_eip.my_eip.id
  subnet_id     = aws_subnet.public_subnet_1.id

  depends_on = [aws_internet_gateway.my_igw]

  tags = {
    Name = "my-nat-gateway"
  }
}

# Asociar una dirección IP elástica (EIP) al NAT Gateway
resource "aws_eip" "my_eip" {
  vpc = true

  tags = {
    Name = "my-eip"
  }
}

# Crear una tabla de ruteo para las subredes públicas
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "public-route-table"
  }
}

# Agregar una regla de ruteo para el Internet Gateway a la tabla de ruteo de las subredes públicas
resource "aws_route" "public_route" {
  route_table_id         = aws_route_table.public_route_table.id
  destination_cidr_block = "0.0.0.0/0" # Ruta por defecto para enviar todo el tráfico a través del IGW
  gateway_id             = aws_internet_gateway.my_igw.id
}

# Asociar la tabla de ruteo de las subredes públicas con las subredes públicas
resource "aws_route_table_association" "public_association_1" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "public_association_2" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_route_table.id
}

# Crear una tabla de ruteo para las subredes privadas
resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "private-route-table"
  }
}

# Agregar una regla de ruteo para el NAT Gateway a la tabla de ruteo de las subredes privadas
resource "aws_route" "private_route" {
  route_table_id         = aws_route_table.private_route_table.id
  destination_cidr_block = "0.0.0.0/0" # Ruta por defecto para enviar todo el tráfico a través del NAT Gateway
  nat_gateway_id         = aws_nat_gateway.my_nat_gateway.id
}

# Asociar la tabla de ruteo de las subredes privadas con las subredes privadas
resource "aws_route_table_association" "private_association_1" {
  subnet_id      = aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.private_route_table.id
}

resource "aws_route_table_association" "private_association_2" {
  subnet_id      = aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.private_route_table.id
}


###################################################################
# Crear un Application Load Balancer (ALB)
resource "aws_lb" "my_alb" {
  name               = "my-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]
  security_groups    = [aws_security_group.alb_sg.id]
}



# Crear un grupo de destino para el ALB
resource "aws_lb_target_group" "my_tg" {
  name     = "my-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.my_vpc.id

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 30
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 10
  }
}

# Crear una regla para el ALB que enrute el tráfico a los grupos de destino
resource "aws_lb_listener_rule" "my_listener_rule" {
  listener_arn = aws_lb_listener.my_listener.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.my_tg.arn
  }

  condition {
    path_pattern {
      values = ["/"]
    }

  }
}

# Crear un listener para el ALB
resource "aws_lb_listener" "my_listener" {
  load_balancer_arn = aws_lb.my_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.my_tg.arn

  }
}

# Crear un security group para el ALB
resource "aws_security_group" "alb_sg" {
  name_prefix = "alb-sg"
  vpc_id      = aws_vpc.my_vpc.id

  ingress {
    from_port = 80
    to_port   = 80
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Crear un grupo de seguridad para el Auto Scaling Group
resource "aws_security_group" "asg_security_group" {
  name_prefix = "asg-sg"
  vpc_id      = aws_vpc.my_vpc.id

  ingress {
    from_port = 0
    to_port   = 65535
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Crear una Launch Template
resource "aws_launch_template" "my_launch_template" {
  name_prefix   = "my-launch-template"
  image_id      = "ami-077d3a0eba6822416"
  vpc_security_group_ids = [aws_security_group.asg_security_group.id]
  instance_type = "t2.micro"
  key_name      = "tc-keys"

  user_data = <<-EOF
ICAgICAgICAgICAgICAjIS9iaW4vYmFzaAogICAgICAgICAgICAgY2QKICAgICAgICAgICAgIGdpdCBpbml0CiAgICAgICAgICAgICBnaXQgcHVsbCBodHRwczovL2dpdGh1Yi5jb20vbWFyaWFuYXJzL3RjLXRlc3QuZ2l0CiAgICAgICAgICAgICBzdWRvIG12IGluZGV4Lmh0bWwgL3Vzci9zaGFyZS9uZ2lueC9odG1sLwogICAgICAgICAgICAgc3VkbyBzeXN0ZW1jdGwgc3RhcnQgbmdpbnggICA=            
              EOF

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "my-instance"
    }
  }
}

# Crear un Auto Scaling Group (ASG)
resource "aws_autoscaling_group" "my_asg" {
  name                 = "my-asg"
  launch_template {
    id      = aws_launch_template.my_launch_template.id
    version = "$Latest"

  }
  vpc_zone_identifier  = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]
  target_group_arns    = [aws_lb_target_group.my_tg.arn]


  # Escalado automático
  min_size             = 1
  max_size             = 1
  desired_capacity     = 1
  health_check_grace_period = 300 # Tiempo de espera después de iniciar una instancia para que los servicios inicien
  health_check_type = "ELB" # Realizar la comprobación de estado de los servicios a través del ALB

  # Políticas de escalado automático
  lifecycle {
    create_before_destroy = true # Crea nuevas instancias antes de destruir las antiguas durante el escalado
  }

  tag {
    key                 = "Name"
    value               = "my-asg"
    propagate_at_launch = true
  }
}

