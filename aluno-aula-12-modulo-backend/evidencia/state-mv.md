# A movimentação do estado

O núcleo do exercício. Seis endereços mudaram no mapa, zero objetos mudaram na AWS.

## Antes: os seis na raiz

Saída de `terraform state list` logo após o `apply` do ponto de partida:

```
aws_athena_workgroup.wg
aws_glue_catalog_database.db
aws_glue_catalog_table.corridas
aws_s3_bucket.lake
aws_s3_bucket.results
aws_s3_bucket_public_access_block.lake
```

Nenhum deles carregava a chave `module` no `terraform.tfstate`. `serial: 7`.

## O diagnóstico, antes de mover

Com o código já em `modules/lake/` e o estado ainda na raiz, o `plan` pediu a
destruição completa:

```
Plan: 6 to add, 0 to change, 6 to destroy.
```

Com o motivo explícito em cada bloco:

```
# aws_s3_bucket.lake will be destroyed
# (because aws_s3_bucket.lake is not in configuration)
```

Os dois conjuntos de endereços, o do código e o do estado, eram disjuntos. Este
plan não foi aplicado.

## Os seis comandos

```
terraform state mv aws_s3_bucket.lake                     module.lake.aws_s3_bucket.lake
terraform state mv aws_s3_bucket_public_access_block.lake module.lake.aws_s3_bucket_public_access_block.lake
terraform state mv aws_s3_bucket.results                  module.lake.aws_s3_bucket.results
terraform state mv aws_glue_catalog_database.db           module.lake.aws_glue_catalog_database.db
terraform state mv aws_glue_catalog_table.corridas        module.lake.aws_glue_catalog_table.corridas
terraform state mv aws_athena_workgroup.wg                module.lake.aws_athena_workgroup.wg
```

Cada um respondeu `Successfully moved 1 object(s).`

## Depois: os seis no módulo, com os mesmos IDs

| endereço | id |
| --- | --- |
| `module.lake.aws_s3_bucket.lake` | `eda-a12-jmnfa-lake` |
| `module.lake.aws_s3_bucket_public_access_block.lake` | `eda-a12-jmnfa-lake` |
| `module.lake.aws_s3_bucket.results` | `eda-a12-jmnfa-results` |
| `module.lake.aws_glue_catalog_database.db` | `325583868777:eda_a12_jmnfa` |
| `module.lake.aws_glue_catalog_table.corridas` | `325583868777:eda_a12_jmnfa:corridas` |
| `module.lake.aws_athena_workgroup.wg` | `eda-a12-jmnfa-wg` |

São os mesmos IDs que o `apply` imprimiu em `Creation complete`. O endereço
mudou, o objeto não.

## A prova numérica

`serial` foi de **7 para 13**. Seis escritas no arquivo de estado. Nenhum dos
seis comandos emitiu `Refreshing`, esperou pela rede ou fez chamada à AWS. É a
diferença entre reescrever o mapa e mexer no território.

## O incidente do quarto comando

Colando os seis de uma vez, o bracketed paste do terminal consumiu a primeira
linha:

```
$ ^[[200~terraform state mv aws_s3_bucket.lake module.lake.aws_s3_bucket.lake
bash: $'\E[200~terraform': command not found
```

Cinco moveram, um ficou. O `terraform state list` mostrou o desencontro:

```
aws_s3_bucket.lake                                  <- ficou na raiz
module.lake.aws_athena_workgroup.wg
module.lake.aws_glue_catalog_database.db
module.lake.aws_glue_catalog_table.corridas
module.lake.aws_s3_bucket.results
module.lake.aws_s3_bucket_public_access_block.lake
```

`serial: 12`, ou seja, 7 mais cinco escritas. É o modo de falha nº 3 da rubrica,
esquecer um `state mv`. Um `plan` naquele momento teria dito
`1 to add, 1 to destroy`, uma linha dentro de quatrocentas.

Lição operacional: conferir a movimentação pelo `terraform state list`, que tem
seis linhas, e não pela leitura do `plan`. O sexto comando foi rodado em
seguida, avulso, e o `plan` seguinte deu `No changes`.

## O fechamento

`No changes. Your infrastructure matches the configuration.`

E, no fim do exercício, o `destroy` operou sobre os endereços `module.lake.*`,
sobre os mesmos objetos que o `apply` havia criado.
