# Decisoes do Exercicio 01

Engenharia de Dados, Aula 04. Lake minimo com o schema declarado, sem Crawler.

Autor: Joao Marcelo (jmnfa@cesar.school)
Login/sufixo dos recursos: `eda-grupo01`
Conta: 325583868777, regiao us-east-1

Cada decisao abaixo esta marcada no `infra/template.yaml` no ponto exato do
arquivo em que ela acontece. A numeracao segue a do esqueleto.

---

## DECISAO 04: quantas particoes declarar, e quais

**O que escolhi:** declarar tres particoes, as dos ultimos tres dias (anteontem,
ontem e hoje), que sao as que o `deploy.sh` calcula no momento do deploy. As
outras vinte e sete continuam no S3, pagas e invisiveis para quem consulta.

### Existem duas perguntas aqui dentro, e elas nao sao a mesma

A primeira e de que tamanho e cada fatia do dado. A segunda e quantas fatias eu
registro no catalogo. As duas mexem no custo da consulta, mas em direcoes
diferentes, e trocar uma pela outra leva direto a conclusao errada.

### Pergunta 1: o tamanho da fatia

Particionar existe para que uma consulta leia menos do que o total. O ganho vem
de quao fino o dado esta fatiado, porque o Athena abre a fatia inteira em que o
filtro cai, e nao um pedaco dela.

Com os mesmos 117.655.606 bytes de corridas, o efeito da granularidade sobre uma
pergunta que quer um unico dia:

| Fatiamento | Particoes | Uma consulta de um dia le |
| --- | --- | --- |
| nenhum | 0 | 117.655.606 bytes |
| por mes | 1 | 117.655.606 bytes |
| por dia | 30 | 3.921.495 bytes |
| por hora | 720 | cerca de 163.000 bytes |

Fatiar mais fino barateia a consulta filtrada, e barateia muito: trocar mes por
dia derruba a leitura em trinta vezes, sem mudar uma linha da pergunta.

Essa parte, porem, nao e uma decisao que este template toma. O layout chega
pronto do gerador, que grava uma pasta por dia em `raw/corridas/dt=AAAA-MM-DD/`.
A granularidade de um dia ja esta dada, e eu a herdo.

### Pergunta 2: quantas fatias registrar

Essa sim e minha, e e o que a DECISAO 04 decide de fato.

Sem Crawler, particao no S3 e particao no catalogo sao duas coisas separadas. O
objeto existe no armazenamento, mas o Athena so o enxerga se houver um recurso
`AWS::Glue::Partition` declarado apontando para ele. Nao ha processo nenhum
neste template que faca esse registro sozinho.

O efeito de registrar mais ou menos:

| Particoes registradas | `WHERE dt = 'hoje'` le | `SELECT count(*)` sem filtro le |
| --- | --- | --- |
| 3 | 3.921.495 bytes | 11.765.561 bytes |
| 10 | 3.921.495 bytes | 39.218.535 bytes |
| 30 | 3.921.495 bytes | 117.655.606 bytes |

A coluna do meio nao se move. Declarar a particao de doze de julho nao deixa a
consulta de hoje mais barata, porque ela continua abrindo um arquivo so. O que
cresce e a coluna da direita, a consulta sem filtro, que varre tudo o que
estiver registrado.

O resumo das duas perguntas: quem barateia a consulta e o filtro `WHERE dt =`
somado a granularidade da fatia. A quantidade de particoes no catalogo nao
barateia consulta nenhuma.

### Registrar poucas particoes nao e economia

Essa e a parte que quero deixar escrita porque parece o contrario do que e.

Uma pergunta por um dia que eu nao declarei, digamos `WHERE dt = '2026-07-15'`,
devolve zero linhas e cobra quase nada, porque leu quase nada. Isso se parece com
economia. Nao e. Quem perguntou recebeu uma resposta vazia sem nenhum sinal de
que aquele dia existe no S3 e apenas nao esta catalogado. Nao ha erro, nao ha
aviso, nao ha entrada de log.

O barato, neste caso, nao veio de ler menos para chegar na mesma resposta. Veio
de nao responder. Sao vinte e sete dias de corrida que estao no armazenamento,
aparecem na fatura do S3, e para qualquer pergunta feita a essa tabela nao
existem.

### O que a pergunta de negocio exige

A pergunta que motivou o lake e "quais bairros do Recife concentram corridas na
madrugada, e desde quando". A segunda metade dela, o "desde quando", quer saber
a partir de que momento o padrao aparece.

Tres particoes dao tres dias de janela. Tres dias nao respondem "desde quando",
respondem "anteontem, ontem e hoje". Quem consultar essa tabela vai receber um
resultado correto sobre um recorte que nao e o da pergunta, e nao tem como notar
isso pela resposta.

Essa e uma limitacao real da minha entrega, e prefiro registra-la aqui a fingir
que tres particoes atendem o caso de uso.

### Por que fiquei em tres mesmo assim

O `deploy.sh` calcula exatamente tres datas, `hoje-2`, `hoje-1` e `hoje`, e passa
tres overrides fixos para o template. Declarar uma quarta particao exigiria
mudar o `deploy.sh` alem do `template.yaml`, e o `deploy.sh` nao faz parte do que
eu entrego. Quem lesse a minha entrega nao conseguiria reproduzir a stack, porque
faltaria a peca que passa as datas extras.

Entao a escolha aqui nao foi entre tres e trinta. Foi entre tres particoes e um
ferramental coerente, ou mais particoes e uma entrega que nao se reproduz. Fiquei
com tres, e registro o que isso custa nas duas secoes acima.

### O efeito colateral sobre o teto

Com tres particoes registradas, a consulta sem filtro varre cerca de 11.765.561
bytes, e a consulta filtrada varre 3.921.495. O teto da DECISAO 05 precisa cair
entre esses dois numeros, e a AWS impoe um piso de 10.485.760 bytes para
`BytesScannedCutoffPerQuery`.

A janela util fica entre 10.485.760 e 11.765.560 bytes, cerca de 1,28 MB, algo
como 11% de folga. E uma margem estreita: se uma das tres particoes sair menor
que a media, a consulta sem filtro passa por baixo do teto e o freio deixa de
tocar exatamente na consulta que ele existe para barrar. Por isso o numero
da DECISAO 05 sai de medicao, e nao da media que eu estimei aqui.

Se eu pudesse declarar cinco particoes, a consulta sem filtro subiria para cerca
de 19.609.268 bytes e a folga passaria de 1,28 MB para quase 9 MB. A restricao do
`deploy.sh` custa essa margem.

### O custo que cresce a cada particao declarada

Cada particao e um recurso escrito a mao, com o `Location` apontando para a chave
exata do objeto no S3. Se o `Location` nao bater com a chave, o Athena devolve
zero linha e nenhum erro: a resposta parece certa e nao e, e nada no caminho
sinaliza a diferenca.

E ha um problema que nao se resolve escrevendo mais recursos. Amanha o gerador
produz um dia novo. Esse dia chega ao S3 pelo `aws s3 sync` e nao chega ao
catalogo, porque neste template nao existe nenhum processo que registre particao:
o registro so acontece quando alguem edita o arquivo e roda o deploy outra vez.
No dia seguinte, a particao que hoje e a mais recente passa a ser a de ontem, e o
catalogo para de refletir o armazenamento ate que esse deploy aconteca.

Declarar particao a mao, portanto, nao e um trabalho que se faz uma vez. E um
trabalho que se repete a cada dia novo, indefinidamente, ou a tabela envelhece em
silencio. Subir de tres para trinta nao resolve isso, apenas adia o mesmo
problema em vinte e sete dias.

### Resumo

| Eixo | Efeito |
| --- | --- |
| Granularidade da fatia (um dia) | barateia a consulta filtrada, e nao e decisao minha |
| Filtro `WHERE dt =` na consulta | e o que de fato derruba o custo, de 11,77 MB para 3,92 MB |
| Numero de particoes registradas | nao muda a consulta filtrada, so a sem filtro |
| Registrar poucas | nao economiza, esconde dado e devolve resposta vazia sem aviso |
| Registrar muitas | alarga a folga do teto e multiplica o trabalho manual |
| Particao do dia seguinte | ninguem registra, com tres ou com trinta |

---

## DECISAO 01: o tipo da coluna `valor`

*Pendente. Opcoes no esqueleto: `double`, `string` ou `decimal(10,2)`. Em cerca
de 1,5% dos eventos (7.688 de 518.400) o produtor manda o valor como texto com
virgula decimal, no formato `"17,82"`. A justificativa precisa dizer o que eu
aceito perder.*

---

## DECISAO 02: o tipo das colunas de tempo

*Pendente. Aplica-se a `data_corrida` e `fim`. Opcoes: `timestamp` ou `string`.
O produtor emite no formato `AAAA-MM-DDTHH:MM:SSZ`. O esqueleto exige que a
justificativa relate o que o SELECT devolveu de verdade, nao o que eu supus.*

---

## DECISAO 03: `ignore.malformed.json`

*Pendente. Opcoes: `"true"`, em que a linha quebrada vira nulo e a consulta
responde, ou `"false"`, em que uma linha ruim derruba a consulta inteira com
`HIVE_BAD_DATA`. A justificativa precisa dizer quem paga a conta de cada
escolha.*

---

## DECISAO 05: o teto de bytes por consulta

*Pendente. Depende do numero de particoes fixado na DECISAO 04. O piso de
10.485.760 bytes e da AWS; o teto util maximo declarado no esqueleto e
117.655.605 bytes, um byte a menos que o lake inteiro. O valor escolhido precisa
reprovar a consulta sem filtro e aprovar a consulta filtrada.*
