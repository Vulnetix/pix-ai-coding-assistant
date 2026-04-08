data "cloudflare_zone" "vulnetix" {
  zone_id = var.cloudflare_zone_id
}

# Legacy — keep until ai-docs.vulnetix.com migration is verified
resource "cloudflare_dns_record" "claude_docs" {
  zone_id = var.cloudflare_zone_id
  name    = "claude-docs.vdb"
  type    = "CNAME"
  content = "vulnetix.github.io"
  proxied = false
  ttl     = 300
}

# New domain for AI coding assistant docs
resource "cloudflare_dns_record" "ai_docs" {
  zone_id = var.cloudflare_zone_id
  name    = "ai-docs"
  type    = "CNAME"
  content = "vulnetix.github.io"
  proxied = false
  ttl     = 300
}
