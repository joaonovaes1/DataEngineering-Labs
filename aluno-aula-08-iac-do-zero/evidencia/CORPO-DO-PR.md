# Exercício 02: do zero em Terraform

Lake construído do zero, só em Terraform, schema declarado, sem Crawler.

| Item | Valor |
| --- | --- |
| Login e sufixo | `jmnfa` |
| Conta | 325583868777 |
| Região | us-east-1 |
| Stack | criada, verificada e destruída |

## As cinco decisões

| # | Decisão | Escolha | Base |
| --- | --- | --- | --- |
| 01 | tipo de `valor` | `string` | ~1,5% dos eventos chegam como `"17,82"`; `double`/`decimal` convertem isso em `NULL` sem aviso |
| 02 | tipo de `data_corrida` e `fim` | `string` | testado: `CAST` para `timestamp` retornou `NULL` nas 5 linhas testadas, porque o dado é só hora, sem data |
| 03 | `ignore.malformed.json` | `false` | falha visível é preferível a descarte silencioso numa coluna de faturamento |
| 04 | partições registradas | 7, janela móvel terminando hoje | `2026-08-28` fica fora de propósito; o dado continua no S3, fora do catálogo |
| 05 | teto de bytes | `10485760` | medido: larga 23.859.750 bytes, estreita 3.408.166 bytes, piso da AWS 10.485.760 |

Justificativa completa em [`DECISOES.md`](DECISOES.md).

## Saída do verifica.sh com a stack de pé

```
Exercício 02 — verificação (região us-east-1, hoje 2026-09-04)
----------------------------------------------------------------
Critério 0 — Terraform, schema declarado, sem Crawler (ELIMINATÓRIO)
OK     [0]  requisito atendido (não pontua; libera o resto)
----------------------------------------------------------------
Critério 1 — os cinco outputs de contrato
PASSA  [1]  (10%)  os cinco outputs existem e estão preenchidos.
----------------------------------------------------------------
Critério 2 — schema declarado (≥8 colunas) e partição dt
PASSA  [2]  (25%)  schema com 9 colunas e partição dt.
----------------------------------------------------------------
Critério 3 — ≥3 partições, uma delas a de hoje
PASSA  [3]  (15%)  7 partições, incluindo a de hoje (2026-09-04).
----------------------------------------------------------------
Critério 4 — o teto mata a consulta larga e deixa passar a estreita
       larga:    estado=CANCELLED  motivo=Bytes scanned limit was exceeded
       estreita: estado=SUCCEEDED  bytes=3408166
FALHA  [4]  (15%)  larga_barrada=0 estreita_passou=1
----------------------------------------------------------------
Resumo dos critérios automáticos: 50 / 65 pontos-percentuais
```

Saída completa em [`evidencia/verifica-01-stack-de-pe.txt`](evidencia/verifica-01-stack-de-pe.txt).

## Saída do verifica.sh --pos-destroy

```
Critério 5 — destroy limpo
PASSA  [5]  (15%)  nenhum bucket órfão.
Critério 5: 15/15%
```

Saída completa em [`evidencia/verifica-02-pos-destroy.txt`](evidencia/verifica-02-pos-destroy.txt).

## Observação sobre o critério 4

O verificador marcou FALHA, mas o teto funcionou. A consulta larga foi
interrompida em exatamente 10.485.760 bytes, o teto declarado, com o motivo
`Bytes scanned limit was exceeded`. A consulta estreita respondeu lendo
3.408.166 bytes.

No Athena engine version 3, o corte por `BytesScannedCutoffPerQuery` retorna o
estado `CANCELLED`, não `FAILED`. O `verifica.sh` só reconhece `FAILED` como
corte válido, então classifica o critério como falha mesmo com o corte
correto acontecendo. Não alterei o `verifica.sh`. Análise completa em
[`evidencia/criterio-04-o-teto-funcionou.md`](evidencia/criterio-04-o-teto-funcionou.md).

## Destroy

`terraform destroy` rodou 2 vezes: a primeira, por engano, a partir da pasta
`verificacao/` (sem state, sem efeito); a segunda, a partir de `terraform/`,
destruiu os 14 recursos da stack. Log completo em
[`evidencia/destroy.txt`](evidencia/destroy.txt) e retrato da stack antes do
destroy em [`evidencia/retrato-antes-do-destroy.md`](evidencia/retrato-antes-do-destroy.md).
