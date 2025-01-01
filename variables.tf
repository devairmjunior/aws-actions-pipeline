variable "whatsapp_token" {
  type        = string
  description = "Token do WhatsApp (Cloud API)"
  sensitive   = true
}

variable "verify_token" {
  type        = string
  description = "Verify token usado pelo webhook"
  sensitive   = true
}
