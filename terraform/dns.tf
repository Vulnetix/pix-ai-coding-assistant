data "cloudflare_zone" "vulnetix" {
  zone_id = var.cloudflare_zone_id
}

# AI coding assistant docs — migrated from claude-docs.vdb
resource "cloudflare_dns_record" "ai_docs" {
  zone_id = var.cloudflare_zone_id
  name    = "ai-docs"
  type    = "CNAME"
  content = "vulnetix.github.io"
  proxied = false
  ttl     = 300
}
