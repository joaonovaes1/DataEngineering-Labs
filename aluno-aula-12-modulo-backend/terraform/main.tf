# =============================================================================
# RAIZ — a stack refatorada. Os seis recursos sairam daqui para
# modules/lake/. O que sobra na raiz e a fronteira do sistema: provider,
# variaveis de entrada, backend e o contrato de saida.
# =============================================================================

module "lake" {
  source     = "./modules/lake"
  sufixo     = var.sufixo
  teto_bytes = var.teto_bytes
}
