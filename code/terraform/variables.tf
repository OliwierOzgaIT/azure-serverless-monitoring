
variable "project_name" {
  description = "Short name for the project, used in all resource names. Keep it lowercase with hyphens only (e.g. 'site-monitor')."
  type        = string
  default     = "site-monitor"
}

variable "environment" {
  description = "Deployment environment. Controls resource naming and can be used to toggle features (e.g. 'dev', 'prod')."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "Environment must be 'dev' or 'prod'."
  }
}

variable "location" {
  description = "Azure region for all resources. Choose the region closest to your users to minimise latency."
  type        = string
  default     = "polandcentral"
}

variable "owner" {
  description = "Name or email of the project owner. Used in resource tags for accountability."
  type        = string
  default     = "oliwier-ozga"
}

variable "alert_email" {
  description = "Email address that receives alerts when a monitored site goes down."
  type        = string

}

variable "sites_to_monitor" {
  description = "List of URLs to check. The monitoring function will HTTP GET each one every 5 minutes."
  type        = list(string)
  default = [
    "https://www.google.com",
    "https://www.github.com",
    "https://www.azure.microsoft.com",
    "https://www.cloudflare.com",
    "https://www.wikipedia.org"
  ]
}
