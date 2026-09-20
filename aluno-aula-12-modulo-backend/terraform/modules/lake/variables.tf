# O modulo recebe o que os recursos consomem — nada alem disso.
# A validacao do formato fica na raiz (fronteira do sistema), nao aqui.

variable "sufixo" {
  type        = string
  description = "Sufixo unico que nomeia todos os recursos do lake."
}

variable "teto_bytes" {
  type        = number
  description = "Limite de bytes escaneados por query no workgroup Athena."
}
