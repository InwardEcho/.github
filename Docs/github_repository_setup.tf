# ------------------------------------------------------------------------------
# Provider Configuration
# ------------------------------------------------------------------------------

terraform {
  required_providers {
    github = {
      source  = "hashicorp/github"
      version = "~> 6.0" # This version constraint is compatible with the hashicorp/github provider
    }
  }
}

# Configure the GitHub Provider
# It will use the GITHUB_TOKEN environment variable by default.
# provider "github" {
#   token = var.github_token # If using an input variable
#   owner = var.github_owner # Your GitHub organization or username
# }

# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------

variable "github_owner" {
  description = "Your GitHub organization name or username."
  type        = string
  # Example: default = "my-github-org"
}

variable "managed_repository_names" {
  description = "A list of existing repository names to apply standard configurations to."
  type        = list(string)
  default     = ["my-example-repo", "another-repo-to-manage"] # Replace with your actual list
}

# Variables for Team Slugs (Replace defaults with your actual slugs or provide at runtime)
variable "team_slug_team_leads" {
  description = "Slug for the 'Team Leads' team."
  type        = string
  default     = "placeholder-team-leads"
}

variable "team_slug_qa_leads" {
  description = "Slug for the 'QA Leads' team."
  type        = string
  default     = "placeholder-qa-leads"
}

variable "team_slug_release_managers" {
  description = "Slug for the 'Release Managers' team."
  type        = string
  default     = "placeholder-release-managers"
}

variable "team_slug_tech_leads" {
  description = "Slug for the 'Tech Leads' team."
  type        = string
  default     = "placeholder-tech-leads"
}

variable "team_slug_security_officers" {
  description = "Slug for the 'Security Officers' team."
  type        = string
  default     = "placeholder-security-officers"
}

variable "team_slug_product_owners" {
  description = "Slug for the 'Product Owners' team."
  type        = string
  default     = "placeholder-product-owners"
}

variable "team_slug_senior_developers" {
  description = "Slug for the 'Senior Developers' team (for branch protection dismissal)."
  type        = string
  default     = "placeholder-senior-developers"
}

variable "team_slug_architects" {
  description = "Slug for the 'Architects' team (for branch protection dismissal)."
  type        = string
  default     = "placeholder-architects"
}

variable "team_slug_devops_team" {
  description = "Slug for the 'DevOps Team' (for branch protection push restrictions)."
  type        = string
  default     = "placeholder-devops-team"
}

# Variables for Environment Secrets (Provide these securely, e.g., via TF_VAR_... env vars or a tfvars file)
# These secrets will be applied to ALL repositories in the 'managed_repository_names' list for the respective environment type.
# If you need per-repository secret values, a more complex variable structure (e.g., a map of maps) would be required.
variable "secret_test_api_key" {
  description = "API Key for the Test environment."
  type        = string
  sensitive   = true
}

variable "secret_staging_api_key" {
  description = "API Key for the Staging environment."
  type        = string
  sensitive   = true
}

variable "secret_production_db_password" {
  description = "Database password for the Production environment."
  type        = string
  sensitive   = true
}

# ------------------------------------------------------------------------------
# Data Sources for Teams
# ------------------------------------------------------------------------------

data "github_team" "team_leads" {
  slug = var.team_slug_team_leads
}

data "github_team" "qa_leads" {
  slug = var.team_slug_qa_leads
}

data "github_team" "release_managers" {
  slug = var.team_slug_release_managers
}

data "github_team" "tech_leads" {
  slug = var.team_slug_tech_leads
}

data "github_team" "security_officers" {
  slug = var.team_slug_security_officers
}

data "github_team" "product_owners" {
  slug = var.team_slug_product_owners
}

data "github_team" "senior_developers" {
  slug = var.team_slug_senior_developers
}

data "github_team" "architects" {
  slug = var.team_slug_architects
}

data "github_team" "devops_team" {
  slug = var.team_slug_devops_team
}

# ------------------------------------------------------------------------------
# Data Source for Managed Repositories
# Fetches details for existing repositories to apply settings to.
# ------------------------------------------------------------------------------

data "github_repository" "managed_repos" {
  for_each = toset(var.managed_repository_names)
  name     = each.key
  # owner is implicitly the one configured for the provider, or var.github_owner if set for provider
}

# ------------------------------------------------------------------------------
# Repository Environments
# Applied to each repository in var.managed_repository_names
# ------------------------------------------------------------------------------

resource "github_repository_environment" "test_environment" {
  for_each    = toset(var.managed_repository_names)
  repository  = each.key # Uses the repository name from the loop
  environment = "test"

  reviewers {
    teams = [
      data.github_team.team_leads.id,
      data.github_team.qa_leads.id
    ]
  }

  deployment_branch_policy {
    protected_branches     = false
    custom_branch_policies = true
  }
}

resource "github_repository_environment" "staging_environment" {
  for_each    = toset(var.managed_repository_names)
  repository  = each.key
  environment = "staging"

  reviewers {
    teams = [
      data.github_team.release_managers.id,
      data.github_team.tech_leads.id
    ]
  }

  deployment_branch_policy {
    protected_branches     = false
    custom_branch_policies = true
  }
}

resource "github_repository_environment" "production_environment" {
  for_each    = toset(var.managed_repository_names)
  repository  = each.key
  environment = "production"

  wait_timer = 60

  reviewers {
    teams = [
      data.github_team.release_managers.id,
      data.github_team.security_officers.id,
      data.github_team.product_owners.id
    ]
  }

  deployment_branch_policy {
    protected_branches     = true
    custom_branch_policies = false
  }
}

# ------------------------------------------------------------------------------
# Environment Secrets
# Applied to each repository in var.managed_repository_names for the respective environment.
# ------------------------------------------------------------------------------

resource "github_actions_environment_secret" "test_api_key" {
  for_each        = toset(var.managed_repository_names)
  repository      = each.key
  environment     = github_repository_environment.test_environment[each.key].environment # References the looped environment
  secret_name     = "API_KEY_TEST"
  plaintext_value = var.secret_test_api_key
}

resource "github_actions_environment_secret" "staging_api_key" {
  for_each        = toset(var.managed_repository_names)
  repository      = each.key
  environment     = github_repository_environment.staging_environment[each.key].environment
  secret_name     = "API_KEY_STAGING"
  plaintext_value = var.secret_staging_api_key
}

resource "github_actions_environment_secret" "production_db_password" {
  for_each        = toset(var.managed_repository_names)
  repository      = each.key
  environment     = github_repository_environment.production_environment[each.key].environment
  secret_name     = "DATABASE_PASSWORD_PRODUCTION"
  plaintext_value = var.secret_production_db_password
}

# ------------------------------------------------------------------------------
# Branch Protection Rules for 'main' branch
# Applied to each repository in var.managed_repository_names
# ------------------------------------------------------------------------------

resource "github_branch_protection" "main_branch_protection" {
  for_each      = toset(var.managed_repository_names)
  repository_id = data.github_repository.managed_repos[each.key].node_id # Uses node_id from the data source
  pattern       = "main"

  required_pull_request_reviews {
    required_approving_review_count = 2
    dismiss_stale_reviews           = true
    require_code_owner_reviews      = true

    dismissal_restrictions {
      teams = [
        var.team_slug_senior_developers,
        var.team_slug_architects
      ]
    }
  }

  required_status_checks {
    strict   = true
    contexts = ["Build and Test", "Code Quality Gates", "Security Scan"]
  }

  enforce_admins = true

  restrictions {
    teams = [
      var.team_slug_release_managers,
      var.team_slug_devops_team
    ]
  }

  # Other common and recommended protections:
  require_linear_history = true        # Prevents merge commits, forces squash or rebase.
  allows_force_pushes    = false       # Protects branch history integrity. CRITICAL: Set to false.
  allows_deletions       = false       # Protects against accidental deletion of the main branch. CRITICAL: Set to false.
  # require_signed_commits = true      # Enhances security by verifying commit authenticity.
                                       # Requires developers to set up GPG/SSH commit signing.
                                       # Consider enabling if your team is prepared for this.
  require_conversation_resolution = true # Ensures all review comments are addressed before merging.
}

# ------------------------------------------------------------------------------
# Repository Security & Analysis Settings
# Applied to each repository in var.managed_repository_names
# ------------------------------------------------------------------------------

resource "github_repository_dependabot_security_updates" "managed_repo_dependabot_updates" {
  for_each   = toset(var.managed_repository_names)
  repository = each.key # Uses the repository name from the loop
  enabled    = true
}

# Note on CODEOWNERS:
# For `require_code_owner_reviews = true` to be effective, a CODEOWNERS file
# must exist in the repository (typically at .github/CODEOWNERS, docs/CODEOWNERS, or CODEOWNERS in root).
# This file defines individuals or teams responsible for code in different parts of the repository.
# Managing the CODEOWNERS file content itself is usually done directly in the Git repository, not via Terraform.

# Organization level settings and CodeQL default setup are omitted for brevity.