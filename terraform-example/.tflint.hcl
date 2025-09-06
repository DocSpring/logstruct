plugin "terraform" {
  enabled = true
}

# Keep linting minimal for example; no cloud plugins required
rule "terraform_unused_declarations" { enabled = true }
rule "terraform_deprecated_index" { enabled = true }
# Soften/noise reduction for examples
rule "terraform_naming_convention" { enabled = false }
rule "terraform_documented_variables" { enabled = false }
rule "terraform_module_pinned_source" { enabled = false }
rule "terraform_required_providers" { enabled = false }
rule "terraform_required_version" { enabled = false }
rule "terraform_standard_module_structure" { enabled = false }
