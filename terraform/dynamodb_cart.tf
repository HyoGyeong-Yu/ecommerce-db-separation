resource "aws_dynamodb_table" "cart" {
  name         = "${var.project_name}-cart"
  billing_mode = "PAY_PER_REQUEST" # On-demand, Free Tier 포함
  hash_key     = "user_id"         # partition key
  range_key    = "product_id"      # sort key

  attribute {
    name = "user_id"
    type = "S"
  }

  attribute {
    name = "product_id"
    type = "S"
  }

  # 장바구니는 7일 후 자동 삭제
  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  tags = { Name = "cart-table", Purpose = "shopping-cart" }
}
