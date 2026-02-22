output "vpc_id" {
  value = aws_vpc.this.id
}

output "public_subnet_a_id" {
  value = aws_subnet.public_a.id
}

output "public_subnet_b_id" {
  value = aws_subnet.public_b.id
}

output "service_subnet_a_id" {
  value = aws_subnet.service_a.id
}

output "service_subnet_b_id" {
  value = aws_subnet.service_b.id
}

output "public_subnet_ids" {
  value = [aws_subnet.public_a.id, aws_subnet.public_b.id]
}

output "service_subnet_ids" {
  value = [aws_subnet.service_a.id, aws_subnet.service_b.id]
}
