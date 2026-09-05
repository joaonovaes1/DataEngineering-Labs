# Critério 4: o teto funcionou, o verificador não reconheceu

## O que o verifica.sh reportou

```
Critério 4 — o teto mata a consulta larga e deixa passar a estreita
       teto declarado: 10485760 bytes
       larga:    estado=CANCELLED  motivo=Bytes scanned limit was exceeded
       estreita: estado=SUCCEEDED  bytes=3408166
FALHA  [4]  (15%)  larga_barrada=0 estreita_passou=1
```

## O que aconteceu de fato

Histórico do workgroup `eda-a08-wg-jmnfa`, consultado via
`aws athena get-query-execution`:

```
SELECT count(*) FROM corridas
  estado: CANCELLED
  motivo: Bytes scanned limit was exceeded
  bytes:  10485760

SELECT count(*) FROM corridas WHERE dt='2026-09-04'
  estado: SUCCEEDED
  motivo: null
  bytes:  3408166
```

A consulta sem filtro foi interrompida em exatamente 10.485.760 bytes, o teto
declarado. A consulta filtrada respondeu normalmente, lendo 3.408.166 bytes.
O comportamento exigido pelo critério ocorreu: o freio tocou na larga e deixou
a estreita passar.

## Por que o script não reconhece

O Athena, na engine version 3, reporta corte por `BytesScannedCutoffPerQuery`
com o estado `CANCELLED`, não `FAILED`. O trecho do `verifica.sh` que decide o
critério:

```bash
larga_morreu="nao"; echo "$lmot" | grep -qiE "bytes|cutoff|exceed" && larga_morreu="sim"
[ "$lest" = "FAILED" ] && [ "$larga_morreu" = "sim" ] && larga_ok=1 || larga_ok=0
```

exige `lest = "FAILED"`. Com `CANCELLED`, essa condição nunca é verdadeira, e
`larga_ok` fica em 0 mesmo com `larga_morreu="sim"`.

## Configuração do workgroup, para conferência

```
EffectiveEngineVersion:        Athena engine version 3
BytesScannedCutoffPerQuery:    10485760
EnforceWorkGroupConfiguration: true
```

## Nota

Não alterei o `verifica.sh`. A saída colada no PR é a do script original, sem
modificação. Este documento existe para registrar o que os números dessa
mesma execução mostram.
