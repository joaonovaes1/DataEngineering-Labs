# Retrato da stack viva, antes do destroy

Conta 325583868777, região us-east-1. Reconstruído a partir dos dados
coletados durante a sessão (schema aplicado via `main.tf`, saída do
`verifica.sh` e consulta ao workgroup), antes de rodar `terraform destroy`.

## A tabela declarada (9 colunas, sem Crawler)

```
Nome:             corridas
Tipo:             EXTERNAL_TABLE
SerDe:            org.openx.data.jsonserde.JsonSerDe
IgnoraMalformado: false
ChaveParticao:    dt

Colunas:
  corrida_id     string
  motorista_id   string
  passageiro_id  string
  bairro         string
  data_corrida   string
  fim            string
  distancia_km   double
  duracao_min    int
  valor          string
```

## As 7 partições declaradas

```
dt=2026-08-29  s3://eda-a08-lake-jmnfa/raw/corridas/dt=2026-08-29/
dt=2026-08-30  s3://eda-a08-lake-jmnfa/raw/corridas/dt=2026-08-30/
dt=2026-08-31  s3://eda-a08-lake-jmnfa/raw/corridas/dt=2026-08-31/
dt=2026-09-01  s3://eda-a08-lake-jmnfa/raw/corridas/dt=2026-09-01/
dt=2026-09-02  s3://eda-a08-lake-jmnfa/raw/corridas/dt=2026-09-02/
dt=2026-09-03  s3://eda-a08-lake-jmnfa/raw/corridas/dt=2026-09-03/
dt=2026-09-04  s3://eda-a08-lake-jmnfa/raw/corridas/dt=2026-09-04/
```

`dt=2026-08-28` não está na lista de propósito (Decisão 04).

## O workgroup e o teto

```
Nome:     eda-a08-wg-jmnfa
Estado:   ENABLED
Teto:     10485760
Forçado:  true
Engine:   Athena engine version 3
```

## Objetos no S3

```
pastas dt= no bucket:        8 (inclui 2026-08-28, fora do catálogo)
partições declaradas no Glue: 7
```
