variable "pr_number" {
  type        = string
  description = "Pull Request number, used in the namespace name"

  validation {
    condition     = can(regex("^[0-9]+$", var.pr_number))
    error_message = "pr_number must only contain digits (e.g. 42)."
  }
}

variable "image" {
  type        = string
  description = "Image to deploy, ideally tagged with the commit SHA"
}

variable "owner" {
  type        = string
  description = "Who owns this preview (cost-control label)"
  default     = "team-a"
}

variable "expires" {
  type        = string
  description = "Date after which the preview can be deleted, YYYY-MM-DD"
  default     = "2026-11-29"

  validation {
    condition     = can(regex("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", var.expires))
    error_message = "expires must be a date like 2026-11-29."
  }
}
