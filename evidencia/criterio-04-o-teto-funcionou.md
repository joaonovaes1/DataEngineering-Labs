# Criterio 4: o teto funcionou, o verificador nao reconheceu

## O que o verifica.sh reportou

```
CRITERIO 4 - o teto mata a larga e deixa passar a estreita (15%)
            consulta larga   (sem WHERE dt): CANCELLED · 10485760 bytes
            consulta estreita (com WHERE dt): SUCCEEDED · 3921495 bytes
            teto declarado: 10485760 bytes
  [FALHA]   a consulta estreita nao respondeu - confira Location e particoes
```

A mensagem de falha diz que a consulta estreita nao respondeu. Ela respondeu:
esta na linha acima, `SUCCEEDED`, com 3.921.495 bytes lidos.

## O que aconteceu de fato

Consultando o historico do workgroup `eda-a04-wg-eda-grupo01`:

```
SELECT count(*) FROM corridas
  estado:  CANCELLED
  motivo:  Bytes scanned limit was exceeded
  bytes:   10485760

SELECT count(*) FROM corridas WHERE dt = '2026-08-22'
  estado:  SUCCEEDED
  motivo:  None
  bytes:   3921495
```

A consulta sem filtro foi interrompida em 10.485.760 bytes, que e exatamente o
teto declarado, com o motivo `Bytes scanned limit was exceeded`. A consulta
filtrada respondeu normalmente lendo 3.921.495 bytes.

O comportamento exigido pelo criterio ocorreu: o freio tocou na larga e deixou
a estreita passar.

## Por que o script nao reconheceu

O Athena, na engine version 3, reporta corte por `BytesScannedCutoffPerQuery`
com o estado `CANCELLED`, e nao `FAILED`.

A funcao que aguarda o fim da consulta ja trata `CANCELLED` como estado
terminal:

```bash
case "$est" in
  SUCCEEDED|FAILED|CANCELLED)
```

Mas o veredito aceita apenas `FAILED`:

```bash
if [[ "${larga%%|*}" == "FAILED" && "${estreita%%|*}" == "SUCCEEDED" ]]; then
  ok "o freio tocou na larga e deixou a estreita passar"
elif [[ "${larga%%|*}" == "SUCCEEDED" ]]; then
  nao "a consulta larga passou - o teto esta alto demais para ser sentido"
else
  nao "a consulta estreita nao respondeu - confira Location e particoes"
fi
```

Com `CANCELLED`, a execucao cai no `else`, cuja mensagem descreve um problema
diferente do que ocorreu.

## Configuracao do workgroup, para conferencia

```
EffectiveEngineVersion:         Athena engine version 3
SelectedEngineVersion:          AUTO
BytesScannedCutoffPerQuery:     10485760
EnforceWorkGroupConfiguration:  True
```

## Nota

Nao alterei o `verifica.sh`. A saida colada no PR e a do script original, sem
modificacao, e este documento existe para registrar o que os numeros dessa
mesma saida mostram.
