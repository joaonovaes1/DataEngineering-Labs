# O modulo expoe os quatro valores que vem de recurso. O quinto output de
# contrato (teto_bytes) e uma variavel de entrada, entao a raiz le direto.

output "bucket_name"    { value = aws_s3_bucket.lake.bucket }
output "database_name"  { value = aws_glue_catalog_database.db.name }
output "table_name"     { value = aws_glue_catalog_table.corridas.name }
output "workgroup_name" { value = aws_athena_workgroup.wg.name }
