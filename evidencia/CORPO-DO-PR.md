# Exercício 01: o schema é seu

Lake mínimo com o schema **declarado**, sem Crawler e sem papel IAM.

| Item | Valor |
| --- | --- |
| Login e sufixo | `eda-grupo01` |
| Conta | 325583868777 |
| Região | us-east-1 |
| Stack | `eda-a04-eda-grupo01`, criada, verificada e destruída |

## As cinco decisões

| | Decisão | Escolha | Base |
| --- | --- | --- | --- |
| 01 | tipo de `valor` | `string` | 7.688 eventos chegam como `"9,49"`; com `double` somem R$ 134.749,67, 1,49% da receita |
| 02 | tipo de `data_corrida` e `fim` | `timestamp` | testado na stack: converteu 17.280 de 17.280, zero nulos |
| 03 | `ignore.malformed.json` | `"true"` | teste forçado: `"false"` derruba a tabela, mas só em consultas que projetam coluna |
| 04 | quantas partições | 3 | limite do `deploy.sh`, que passa três datas fixas |
| 05 | teto de bytes | `10485760` | medido: entre 3.921.495 e 11.765.273 bytes, com piso da AWS em 10 MiB |

A justificativa completa está em [`DECISOES.md`](DECISOES.md).

Duas delas partiram do mesmo critério e chegaram a conclusões opostas: declarar o
tipo mais forte que o dado real suporta sem perda. Em `valor` isso é `string`,
porque o dado não suporta `double`. Em `data_corrida` isso é `timestamp`, porque
o dado suporta. A DECISÃO 02 refutou a hipótese com que comecei, e o registro
disso está no arquivo.

## Saída do verifica.sh com a stack de pé

```
[PASSA]   nenhum Crawler, e ha AWS::Glue::Table
          BucketName = eda-a04-lake-eda-grupo01
          DatabaseName = eda_a04_raw_eda-grupo01
          TableName = corridas
          WorkGroupName = eda-a04-wg-eda-grupo01
          TetoBytes = 10485760
[PASSA]   os cinco existem e estao preenchidos
          colunas declaradas: 9
          chave de particao: dt
[PASSA]   ≥ 8 colunas e chave de particao dt
          valor foi declarado como: string  (DECISAO 01 - justifique)
          particoes registradas: 3
          a particao de hoje (2026-08-22) esta declarada: sim
[PASSA]   ≥ 3 particoes, e a de hoje esta entre elas
[PASSA]   todo Location bate com a chave dt= do objeto
          consulta larga   (sem WHERE dt): CANCELLED · 10485760 bytes
          consulta estreita (com WHERE dt): SUCCEEDED · 3921495 bytes
          teto declarado: 10485760 bytes
[FALHA]   a consulta estreita nao respondeu - confira Location e particoes
          decisoes encontradas no arquivo: 5 de 5
[PASSA]   as cinco decisoes aparecem (o texto e lido por uma pessoa)
resumo: 1 criterio(s) em FALHA
```

## Saída do verifica.sh --pos-destroy

```
[PASSA]   nenhum recurso orfao
```

## Observação sobre o critério 4

O verificador marcou FALHA, e os números da própria saída mostram que o teto
funcionou:

```
consulta larga   (sem WHERE dt): CANCELLED · 10485760 bytes
consulta estreita (com WHERE dt): SUCCEEDED · 3921495 bytes
teto declarado: 10485760 bytes
```

A consulta sem filtro foi interrompida em exatamente 10.485.760 bytes, o teto
declarado, com o motivo `Bytes scanned limit was exceeded` registrado no
histórico do workgroup. A consulta filtrada respondeu lendo 3.921.495 bytes. O
comportamento exigido pelo critério ocorreu.

O Athena, na engine version 3, reporta corte por `BytesScannedCutoffPerQuery` com
estado `CANCELLED`, e não `FAILED`. O `verifica.sh` já trata `CANCELLED` como
estado terminal na função que aguarda a consulta, mas o veredito aceita apenas
`FAILED`, e por isso a execução cai no `else`, cuja mensagem descreve um problema
diferente do que ocorreu.

Não alterei o `verifica.sh`: as saídas acima são do script original. A análise
completa está em
[`evidencia/criterio-04-o-teto-funcionou.md`](evidencia/criterio-04-o-teto-funcionou.md).

## Limpeza

```
esvaziando s3://eda-a04-lake-eda-grupo01
apagando a stack eda-a04-eda-grupo01

conferencia:
  [limpo]    stack
  [limpo]    bucket
  [limpo]    database
  [limpo]    tabela
  [limpo]    workgroup

conta limpa: nenhum recurso desta stack sobrou.
```

Conferência adicional filtrando pelo login: stack, bucket, database e workgroup
todos ausentes. Os recursos `eda-a04-eda-grupo07` e `eda-a04-boh` que aparecem na
conta pertencem a outras pessoas e não foram tocados.
