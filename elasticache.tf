resource "aws_elasticache_subnet_group" "redis_subnet_group" {
  name       = "iac-redis-subnet-group"
  subnet_ids = [aws_subnet.private_data_1.id, aws_subnet.private_data_2.id]

  tags = {
    Name = "IAC-Redis-Subnet-Group"
  }
}

resource "aws_elasticache_replication_group" "redis" {
  replication_group_id       = "iac-redis-cluster"
  description                = "Redis cluster for session management and caching"
  node_type                  = "cache.t3.medium"
  port                       = 6379
  parameter_group_name       = "default.redis7"
  automatic_failover_enabled = true
  multi_az_enabled           = true
  num_cache_clusters         = 2
  subnet_group_name          = aws_elasticache_subnet_group.redis_subnet_group.name
  security_group_ids         = [aws_security_group.redis_sg.id]

  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  auth_token                 = var.redis_auth_token

  tags = {
    Name = "IAC-Redis-Cluster"
  }
}
