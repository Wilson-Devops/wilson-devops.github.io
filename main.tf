data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 2)
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "${var.environment}-vpc"
    Environment = var.environment
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.environment}-igw"
    Environment = var.environment
  }
}

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index + 1)
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.environment}-public-${count.index + 1}"
    Tier = "public"
  }
}

resource "aws_subnet" "app" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 10)
  availability_zone = local.azs[count.index]

  tags = {
    Name = "${var.environment}-app-${count.index + 1}"
    Tier = "application"
  }
}

resource "aws_subnet" "data" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 20)
  availability_zone = local.azs[count.index]

  tags = {
    Name = "${var.environment}-data-${count.index + 1}"
    Tier = "data"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name        = "${var.environment}-public-rt"
    Environment = var.environment
  }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_eip" "nat" {
  domain = "vpc"
  tags = {
    Name = "${var.environment}-nat-eip"
  }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name        = "${var.environment}-nat"
    Environment = var.environment
  }

  depends_on = [aws_internet_gateway.main]
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name        = "${var.environment}-private-rt"
    Environment = var.environment
  }
}

resource "aws_route_table_association" "app" {
  count          = 2
  subnet_id      = aws_subnet.app[count.index].id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "data" {
  count          = 2
  subnet_id      = aws_subnet.data[count.index].id
  route_table_id = aws_route_table.private.id
}

resource "aws_security_group" "alb" {
  name        = "${var.environment}-alb-sg"
  description = "Allow web traffic to the load balancer"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "app" {
  name        = "${var.environment}-app-sg"
  description = "Allow traffic from the load balancer to the app tier"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "db" {
  name        = "${var.environment}-db-sg"
  description = "Allow MySQL traffic from the application tier"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "main" {
  name               = "${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  tags = {
    Name        = "${var.environment}-alb"
    Environment = var.environment
  }
}

resource "aws_lb_target_group" "app" {
  name     = "${var.environment}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    enabled             = true
    path                = "/"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

resource "aws_launch_template" "app" {
  name_prefix   = "${var.environment}-app-"
  image_id      = data.aws_ami.amazon_linux_2.id
  instance_type = var.instance_type

  vpc_security_group_ids = [aws_security_group.app.id]

  user_data = base64encode(<<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd
              systemctl enable httpd
              systemctl start httpd
              cat > /var/www/html/index.html <<'HTML'
              <!doctype html>
              <html>
                <head>
                  <meta charset="utf-8">
                  <title>Wilson Manda - AWS DevOps Engineer</title>
                  <style>
                    :root {
                      --bg: #07111f;
                      --card: #0f111a;
                      --text: #e2e8f0;
                      --muted: #94a3b8;
                      --accent: #38bdf8;
                      --accent2: #60a5fa;
                      --nav-bg: rgba(7, 17, 31, 0.92);
                      --header-bg: linear-gradient(90deg, var(--accent), var(--accent2));
                      --section-shadow: 0 12px 30px rgba(0, 0, 0, 0.25);
                    }
                    body.light {
                      --bg: #f8fafc;
                      --card: #ffffff;
                      --text: #0f172a;
                      --muted: #475569;
                      --accent: #2563eb;
                      --accent2: #38bdf8;
                      --nav-bg: rgba(255, 255, 255, 0.95);
                      --section-shadow: 0 12px 30px rgba(15, 23, 42, 0.12);
                    }
                    * { box-sizing: border-box; }
                    body {
                      font-family: 'Segoe UI', Arial, sans-serif;
                      margin: 0;
                      padding: 0;
                      min-height: 100vh;
                      background: linear-gradient(135deg, var(--bg), #0f172a);
                      color: var(--text);
                      transition: background 0.3s ease, color 0.3s ease;
                    }
                    header {
                      background: var(--header-bg);
                      color: white;
                      padding: 3rem 1rem 2rem;
                      text-align: center;
                      position: relative;
                    }
                    .profile-image {
                      width: 140px;
                      height: 140px;
                      border-radius: 50%;
                      object-fit: cover;
                      border: 4px solid rgba(255, 255, 255, 0.35);
                      box-shadow: 0 18px 40px rgba(0, 0, 0, 0.25);
                      margin-bottom: 1.25rem;
                    }
                    header h1 { font-size: 2.4rem; margin-bottom: 0.5rem; }
                    header p { font-size: 1rem; margin: 0.3rem 0; color: #e2e8f0; }
                    nav { background: var(--nav-bg); position: sticky; top: 0; z-index: 10; padding: 1rem; text-align: center; display: flex; flex-wrap: wrap; align-items: center; justify-content: center; gap: 0.75rem; }
                    nav a { color: white; margin: 0 0.4rem; text-decoration: none; font-weight: 600; }
                    nav a:hover { color: #7dd3fc; }
                    .theme-toggle {
                      border: none;
                      border-radius: 999px;
                      padding: 0.65rem 1rem;
                      background: rgba(255, 255, 255, 0.12);
                      color: white;
                      cursor: pointer;
                      font-weight: 700;
                      transition: background 0.2s ease, transform 0.2s ease;
                    }
                    .theme-toggle:hover { background: rgba(255, 255, 255, 0.2); transform: translateY(-1px); }
                    .container { max-width: 1000px; margin: 0 auto; padding: 1rem; }
                    section { background: var(--card); margin: 1.5rem 0; padding: 1.8rem 2rem; border-radius: 14px; box-shadow: var(--section-shadow); transition: transform 0.25s ease, box-shadow 0.25s ease; }
                    section:hover { transform: translateY(-4px); }
                    h2 { color: var(--accent); margin-top: 0; }
                    .hero { font-size: 1.05rem; color: var(--muted); line-height: 1.8; }
                    .chip { display: inline-block; background: #dbeafe; color: #1d4ed8; padding: 0.35rem 0.8rem; border-radius: 999px; margin: 0.25rem 0.35rem 0.25rem 0; font-size: 0.92rem; transition: transform 0.2s ease, box-shadow 0.2s ease; }
                    .chip:hover { transform: translateY(-3px); box-shadow: 0 6px 12px rgba(37, 99, 235, 0.2); }
                    ul { padding-left: 1.2rem; }
                    .contact-list { list-style-type: none; padding: 0; margin: 0; }
                    .contact-list li { margin-bottom: 0.5rem; }
                    a { color: var(--accent); }
                    .resume-link { display: inline-block; margin-top: 0.8rem; padding: 0.75rem 1.2rem; border-radius: 999px; background: var(--accent); color: white; text-decoration: none; transition: background 0.2s ease; }
                    .resume-link:hover { background: var(--accent2); }
                  </style>
                </head>
                <body>
                  <header>
                    <img class="profile-image" src="data:image/jpeg;base64,${trimspace(file("${path.module}/IMG_9966-tiny.base64"))}" alt="Wilson Manda profile">
                    <h1>Wilson Manda</h1>
                    <p>AWS DevOps Engineer | DevSecOps | Cloud Automation | Terraform | Kubernetes</p>
                    <p>Hyderabad, India | wilson.devops@gmail.com | +91-9959183594</p>
                    <p><a href="https://linkedin.com/in/wilsonmanda" style="color: white;">linkedin.com/in/wilsonmanda</a></p>
                  </header>
                  <nav>
                    <a href="#home">Home</a>
                    <a href="#about">About Me</a>
                    <a href="#skills">Skills</a>
                    <a href="#projects">Projects</a>
                    <a href="#certifications">Certifications</a>
                    <a href="#resume">Resume</a>
                    <a href="#contact">Contact</a>
                    <button id="themeToggle" class="theme-toggle" type="button">Light Mode</button>
                  </nav>
                  <div class="container">
                    <section id="home">
                      <h2>Home</h2>
                      <p class="hero">AWS DevOps Engineer with 5+ years of experience designing, implementing, and automating cloud infrastructure, CI/CD pipelines, security controls, and platform operations across enterprise environments.</p>
                    </section>
                    <section id="about">
                      <h2>About Me</h2>
                      <p>I build secure, scalable AWS environments using Infrastructure as Code, DevSecOps practices, and automation. My work includes cloud governance, compliance automation, Active Directory integration, Golden AMI creation, and CI/CD modernization.</p>
                    </section>
                    <section id="skills">
                      <h2>Skills</h2>
                      <div>
                        <span class="chip">AWS</span>
                        <span class="chip">Terraform</span>
                        <span class="chip">Jenkins</span>
                        <span class="chip">Docker</span>
                        <span class="chip">Kubernetes</span>
                        <span class="chip">Ansible</span>
                        <span class="chip">Python</span>
                        <span class="chip">Cloud Custodian</span>
                        <span class="chip">Git</span>
                        <span class="chip">Linux</span>
                      </div>
                    </section>
                    <section id="projects">
                      <h2>Projects</h2>
                      <ul>
                        <li><strong>Core Security Cloud Custodian</strong> - compliance automation policies and Jenkins integration for automated remediation.</li>
                        <li><strong>AWS Managed Active Directory & Access Automation</strong> - automated domain join and onboarding for Linux and Windows EC2 instances.</li>
                        <li><strong>Kali Pen Test Deployment</strong> - Jenkins pipeline automation for security test environments and GitHub release workflows.</li>
                        <li><strong>Core Infrastructure Deployment</strong> - reusable Terraform modules for VPC, subnets, NAT, bastion hosts, and multi-account AWS onboarding.</li>
                        <li><strong>Golden AMI Automation</strong> - Packer and Jenkins-based AMI build pipelines, OS patching, and security hardening.</li>
                      </ul>
                    </section>
                    <section id="certifications">
                      <h2>Certifications</h2>
                      <ul>
                        <li>AWS Certified Cloud Practitioner</li>
                        <li>AWS Certified Solutions Architect - Associate</li>
                        <li>Terraform Associate</li>
                      </ul>
                    </section>
                    <section id="resume">
                      <h2>Resume</h2>
                      <p>Download a PDF copy of the resume to review detailed experience, achievements, and education.</p>
                      <a class="resume-link" href="#contact">Request Resume</a>
                    </section>
                    <section id="contact">
                      <h2>Contact</h2>
                      <ul class="contact-list">
                        <li>Email: wilson.devops@gmail.com</li>
                        <li>Phone: +91-9959183594</li>
                        <li>LinkedIn: <a href="https://linkedin.com/in/wilsonmanda">linkedin.com/in/wilsonmanda</a></li>
                      </ul>
                    </section>
                  </div>
                  <script>
                    const themeToggle = document.getElementById('themeToggle');
                    const setTheme = (theme) => {
                      document.body.classList.toggle('light', theme === 'light');
                      themeToggle.textContent = theme === 'light' ? 'Dark Mode' : 'Light Mode';
                      localStorage.setItem('theme', theme);
                    };
                    const savedTheme = localStorage.getItem('theme') || 'dark';
                    setTheme(savedTheme);
                    themeToggle.addEventListener('click', () => {
                      const nextTheme = document.body.classList.contains('light') ? 'dark' : 'light';
                      setTheme(nextTheme);
                    });
                  </script>
                </body>
              </html>
              HTML
              EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${var.environment}-app"
      Environment = var.environment
    }
  }
}

resource "aws_autoscaling_group" "app" {
  name                = "${var.environment}-asg"
  desired_capacity    = 2
  min_size            = 2
  max_size            = 4
  vpc_zone_identifier = aws_subnet.app[*].id
  target_group_arns   = [aws_lb_target_group.app.arn]
  health_check_type   = "ELB"

  launch_template {
    id      = aws_launch_template.app.id
    version = aws_launch_template.app.latest_version
  }

  instance_refresh {
    strategy = "Rolling"

    preferences {
      min_healthy_percentage = 100
      instance_warmup        = 120
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.environment}-app"
    propagate_at_launch = true
  }
}

resource "aws_db_subnet_group" "main" {
  name       = "${var.environment}-db-subnet-group"
  subnet_ids = aws_subnet.data[*].id

  tags = {
    Name        = "${var.environment}-db-subnet-group"
    Environment = var.environment
  }
}

resource "aws_db_instance" "main" {
  identifier              = "${var.environment}-mysql"
  allocated_storage       = 20
  storage_type            = "gp2"
  engine                  = "mysql"
  instance_class          = "db.t3.micro"
  username                = var.db_username
  password                = var.db_password
  db_name                 = "appdb"
  db_subnet_group_name    = aws_db_subnet_group.main.name
  vpc_security_group_ids  = [aws_security_group.db.id]
  skip_final_snapshot     = true
  publicly_accessible     = false
  multi_az                = false
  backup_retention_period = 0

  tags = {
    Name        = "${var.environment}-mysql"
    Environment = var.environment
  }
}
