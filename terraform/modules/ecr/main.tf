resource "aws_ecr_repository" "service" {
  for_each = toset(var.service_names)

  name                 = "shop-${each.value}"
  image_tag_mutability = "MUTABLE" # deploy.yml always pushes the ":latest" tag

  image_scanning_configuration {
    scan_on_push = true
  }
  force_delete = true

  tags = merge(var.tags, { Name = "${var.project_name}-${var.environment}-shop-${each.value}" })
}

# Keep only the most recent N images per repo so ECR storage doesn't
# grow unbounded across repeated pushes to the same "latest" tag.
resource "aws_ecr_lifecycle_policy" "service" {
  for_each   = aws_ecr_repository.service
  repository = each.value.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last ${var.max_image_count} images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = var.max_image_count
      }
      action = {
        type = "expire"
      }
    }]
  })
}

# ── CROSS-REGION REPLICATION ─────────────────────────────────
# Images are only ever built/pushed once, in the primary region's CI/CD
# job. ECR replication mirrors every push to the DR region automatically
# so the standby app host can `docker pull` locally during a failover
# without depending on primary-region network access. Registry-level
# setting: only create this once, from the primary environment
# (replicate_to_region != null).
data "aws_caller_identity" "current" {
  count = var.replicate_to_region != null ? 1 : 0
}

resource "aws_ecr_replication_configuration" "this" {
  count = var.replicate_to_region != null ? 1 : 0

  replication_configuration {
    rule {
      destination {
        region      = var.replicate_to_region
        registry_id = data.aws_caller_identity.current[0].account_id
      }
    }
  }
}
