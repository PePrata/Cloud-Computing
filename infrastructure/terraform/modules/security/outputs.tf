output "api_gateway_security_group_id" {
  value = aws_security_group.api_gateway.id
}

output "user_service_security_group_id" {
  value = aws_security_group.user_service.id
}

output "product_service_security_group_id" {
  value = aws_security_group.product_service.id
}

output "order_service_security_group_id" {
  value = aws_security_group.order_service.id
}

output "rds_security_group_id" {
  value = aws_security_group.rds.id
}

output "msk_security_group_id" {
  value = aws_security_group.msk.id
}
