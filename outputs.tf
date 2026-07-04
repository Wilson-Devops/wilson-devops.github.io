output "vpc_id" {
  value = aws_vpc.main.id
}

output "load_balancer_dns_name" {
  value = aws_lb.main.dns_name
}

output "database_endpoint" {
  value = aws_db_instance.main.address
}

output "application_tier_subnets" {
  value = aws_subnet.app[*].id
}

output "data_tier_subnets" {
  value = aws_subnet.data[*].id
}
