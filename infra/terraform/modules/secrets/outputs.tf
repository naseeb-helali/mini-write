output "database_secret_arn" {
  description = "ARN of the database secret."

  value = aws_secretsmanager_secret.database.arn
}

output "redis_secret_arn" {
  description = "ARN of the Redis secret."

  value = aws_secretsmanager_secret.redis.arn
}

output "jwt_secret_arn" {
  description = "ARN of the JWT secret."

  value = aws_secretsmanager_secret.jwt.arn
}