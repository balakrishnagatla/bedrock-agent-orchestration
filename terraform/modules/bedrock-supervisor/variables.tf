variable "agent_name" {
  description = "Name of the supervisor agent."
  type        = string
}

variable "agent_description" {
  type    = string
  default = "Top-level orchestrator that routes requests to specialist collaborator agents."
}

variable "foundation_model" {
  type = string
}

variable "instruction" {
  type = string

  validation {
    condition     = length(var.instruction) >= 40
    error_message = "instruction must be at least 40 characters."
  }
}

variable "agent_collaboration" {
  description = "SUPERVISOR (agent decides when/whether to delegate) or SUPERVISOR_ROUTER (every turn is routed to a collaborator)."
  type        = string
  default     = "SUPERVISOR"

  validation {
    condition     = contains(["SUPERVISOR", "SUPERVISOR_ROUTER"], var.agent_collaboration)
    error_message = "agent_collaboration must be SUPERVISOR or SUPERVISOR_ROUTER."
  }
}

variable "collaborators" {
  description = "Map of collaborator_key => { collaborator_name, instruction, agent_alias_arn, relay_conversation_history }."
  type = map(object({
    collaborator_name          = string
    instruction                 = string
    agent_alias_arn             = string
    relay_conversation_history  = optional(string, "TO_COLLABORATOR")
  }))
}

variable "idle_session_ttl_seconds" {
  type    = number
  default = 900
}

variable "guardrail_id" {
  type    = string
  default = null
}

variable "guardrail_version" {
  type    = string
  default = "DRAFT"
}

variable "kms_key_arn" {
  type    = string
  default = null
}

variable "create_alias" {
  type    = bool
  default = true
}

variable "alias_name" {
  type    = string
  default = "live"
}

variable "tags" {
  type    = map(string)
  default = {}
}
