# Retrato da stack viva, antes do destroy

Capturado em 2026-08-22 14:11 na conta 325583868777, regiao us-east-1.
Depois do destroy estes recursos deixam de existir; este arquivo e a prova
de como o catalogo estava quando o verifica.sh rodou.

## A tabela declarada (9 colunas, sem Crawler)
```
{
    "Nome": "corridas",
    "Tipo": "EXTERNAL_TABLE",
    "SerDe": "org.openx.data.jsonserde.JsonSerDe",
    "IgnoraMalformado": "true",
    "ChaveParticao": [
        "dt"
    ],
    "Colunas": [
        [
            "corrida_id",
            "string"
        ],
        [
            "motorista_id",
            "string"
        ],
        [
            "passageiro_id",
            "string"
        ],
        [
            "bairro",
            "string"
        ],
        [
            "data_corrida",
            "timestamp"
        ],
        [
            "fim",
            "timestamp"
        ],
        [
            "distancia_km",
            "double"
        ],
        [
            "duracao_min",
            "double"
        ],
        [
            "valor",
            "string"
        ]
    ]
}
```

## As tres particoes declaradas
```
-----------------------------------------------------------------------------
|                               GetPartitions                               |
+-------------------------------------------------------------+-------------+
|                          Location                           |     dt      |
+-------------------------------------------------------------+-------------+
|  s3://eda-a04-lake-eda-grupo01/raw/corridas/dt=2026-08-21/  |  2026-08-21 |
|  s3://eda-a04-lake-eda-grupo01/raw/corridas/dt=2026-08-20/  |  2026-08-20 |
|  s3://eda-a04-lake-eda-grupo01/raw/corridas/dt=2026-08-22/  |  2026-08-22 |
+-------------------------------------------------------------+-------------+
```

## O workgroup e o teto
```
{
    "Nome": "eda-a04-wg-eda-grupo01",
    "Estado": "ENABLED",
    "Teto": 10485760,
    "Forcado": true,
    "Engine": "Athena engine version 3"
}
```

## Objetos no S3
```
total de objetos em raw/corridas/: 30
particoes declaradas no catalogo:  3
```
