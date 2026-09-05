# Decisões do Exercício 02

Lake do zero em Terraform, sem Crawler.

| | |
| --- | --- |
| Autor | João Marcelo (jmnfa@cesar.school) |
| Sufixo dos recursos | `jmnfa` |
| Conta | 325583868777, região us-east-1 |

## Decisão 01: tipo de `valor`

Escolhido: `string`.

Cerca de 1,5% dos registros trazem o campo como texto com vírgula, por exemplo
`"17,82"`. Com `double` ou `decimal(10,2)` esse valor vira `NULL` na leitura, sem
erro e sem aviso: uma soma sobre a coluna passa a excluir esses registros e
ninguém percebe. Com `string` o dado sobrevive até a consulta, mas toda operação
aritmética sobre `valor` exige `CAST` explícito daqui em diante. Aceito pagar
esse custo de conversão repetida para não perder faturamento silenciosamente.

## Decisão 02: tipo das colunas de tempo

Escolhido: `string`, para `data_corrida` e `fim`.

Testado na stack em execução, partição `dt=2026-09-04`:

```sql
SELECT data_corrida, fim,
       TRY(CAST(data_corrida AS timestamp)) AS data_ts,
       TRY(CAST(fim AS timestamp)) AS fim_ts
FROM corridas WHERE dt='2026-09-04' LIMIT 5;
```

As 5 linhas retornaram `NULL` em `data_ts` e `fim_ts`. O dado gerado traz só
hora, no formato `HH:MM:SS` (ex.: `02:11:00`), sem data. O tipo `timestamp` do
Hive exige data e hora completas; sem o componente de data, o SerDe não
consegue converter e a coluna inteira vira `NULL`. Declarar `timestamp` aqui
apagaria os dois campos por completo.

## Decisão 03: `ignore.malformed.json`

Escolhido: `false`.

Uma linha de JSON malformado derruba a consulta inteira, mesmo que seja um
registro isolado em milhões. Prefiro essa falha visível a `true`, que
descartaria a linha sem aviso. Como `valor` é uma coluna de faturamento, uma
falha silenciosa poderia esconder perda de receita sem que ninguém saiba
procurar por ela.

## Decisão 04: partições registradas

Escolhido: 7 dias, `2026-08-29` a `2026-09-04`, janela móvel terminando hoje.

O gerador criou 8 dias (`2026-08-28` a `2026-09-04`); o mais antigo,
`2026-08-28`, não foi registrado como partição. Os dados desse dia foram
enviados ao S3 junto com os outros, mas não aparecem em nenhuma consulta:
o Glue Catalog não tem essa partição, e o Athena só enxerga o que está
registrado no catálogo. Amanhã, sem um novo `terraform apply` com a lista de
dias atualizada, a janela para de avançar: o dia mais novo gerado não entra
sozinho, e o mais antigo da janela atual continua registrado mesmo depois de
sair do período que faz sentido consultar.

## Decisão 05: teto de bytes

Escolhido: `10485760` bytes, o piso mínimo aceito pela AWS.

Medido na stack em execução:

| Consulta | Bytes escaneados |
| --- | --- |
| `SELECT count(*) FROM corridas` (7 partições) | 23.859.750 |
| `SELECT count(*) FROM corridas WHERE dt='2026-09-04'` | 3.408.166 |

A faixa válida ficou entre 10.485.760 (piso da AWS) e 23.859.750 (bytes da
consulta larga). A consulta estreita passa com folga em qualquer ponto dessa
faixa (3,4 MB contra um piso de 10 MB); a consulta larga só corre risco de
escapar do corte se o teto se aproximar de 23,8 MB. Como o risco está do lado
da larga, escolhi o extremo oposto: o piso, que maximiza a margem contra ela.

Confirmado no histórico do Athena: a consulta larga foi interrompida em
exatamente 10.485.760 bytes, motivo `Bytes scanned limit was exceeded`; a
estreita rodou normalmente com 3.408.166 bytes.

### Nota sobre o critério 4 e o `verifica.sh`

O `verifica.sh` classifica o critério 4 como falha nesta entrega, mas o teto
funcionou. No Athena engine version 3, uma consulta cortada por
`BytesScannedCutoffPerQuery` recebe o estado `CANCELLED`, não `FAILED`. O
script só reconhece `FAILED` como corte válido, então marca
`larga_barrada=0` mesmo com o corte correto acontecendo. Não alterei o
`verifica.sh`. Números e histórico completo em
`evidencia/criterio-04-o-teto-funcionou.md`.
