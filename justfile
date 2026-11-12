# Pix — plugin tasks.
#
# The docs live in Vulnetix/platform-docs, under https://docs.vulnetix.com/pix/.

default:
    @just --list

# Validate every skill against the Agent Skills spec.
validate:
    skill-validator check --strict --allow-extra-frontmatter --allow-dirs=evals,references skills/

# Check the eval corpus itself: no model, no credential, no cost.
evals:
    node scripts/eval.mjs

# Seeded property tests for the eval harness helpers in scripts/.
test:
    node --test scripts/*.test.mjs

# Drive real agents through the corpus. Costs money and minutes.
evals-full agents="":
    node scripts/eval.mjs --agents{{ if agents != "" { "=" + agents } else { "" } }}

# Record the marketing replays, from the same runs the evals assert on.
record-demos agents="":
    node scripts/record-demos.mjs {{ if agents != "" { "--agents=" + agents } else { "" } }}

# Everything CI checks on a push, in one go.
check: validate test evals

# Install the plugin into the coding agents on this machine.
install:
    vulnetix agent install
