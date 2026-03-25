data "cloudflare_zone" "vulnetix" {
  zone_id = var.cloudflare_zone_id
}

# CNAME record for Claude Code Plugin docs
# Points to GitHub Pages — proxied=false so GH Pages handles TLS
resource "cloudflare_dns_record" "claude_docs" {
  zone_id = var.cloudflare_zone_id
  name    = "claude-docs.vdb"
  type    = "CNAME"
  content = "vulnetix.github.io"
  proxied = false
  ttl     = 300
}
