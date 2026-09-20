# =============================================================================
# BACKEND REMOTO — bloco vazio de proposito. Os valores concretos (bucket, key,
# credenciais de caminho) vem do backend.hcl, que NAO e versionado: ele carrega
# o nome do bucket da conta. Ver backend.hcl.example.
#
# workspace_key_prefix: o workspace `default` grava direto em <key>; qualquer
# workspace nomeado grava em <prefix>/<workspace>/<key>.
# =============================================================================

terraform {
  backend "s3" {
    workspace_key_prefix = "eda-a12"
  }
}
