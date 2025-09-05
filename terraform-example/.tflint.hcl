plugin "terraform" {
  enabled = true
}

# Keep linting minimal for example; no cloud plugins required
rule "terraform_unused_declarations" { enabled = true }
rule "terraform_comment_syntax" { enabled = true }
rule "terraform_deprecated_index" { enabled = true }

