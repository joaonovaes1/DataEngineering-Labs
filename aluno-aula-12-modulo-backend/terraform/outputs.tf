# CONTRATO — o verifica.sh le estes nomes. Preservados na refatoracao: os
# valores continuam identicos, so mudou de onde sao lidos.

output "bucket_name"    { value = module.lake.bucket_name }
output "database_name"  { value = module.lake.database_name }
output "table_name"     { value = module.lake.table_name }
output "workgroup_name" { value = module.lake.workgroup_name }
output "teto_bytes"     { value = var.teto_bytes }
