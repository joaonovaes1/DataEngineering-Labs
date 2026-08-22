# Decisoes do Exercicio 01

Engenharia de Dados, Aula 04. Lake minimo com o schema declarado, sem Crawler.

Autor: Joao Marcelo (jmnfa@cesar.school)
Login/sufixo dos recursos: `eda-grupo01`
Conta: 325583868777, regiao us-east-1

Cada decisao abaixo esta marcada no `infra/template.yaml` no ponto exato do
arquivo em que ela acontece. A numeracao segue a do esqueleto.

---

## DECISAO 04: quantas particoes declarar, e quais

**O que escolhi:** declarar tres particoes, sendo a terceira a de hoje. As
outras vinte e sete continuam no S3, pagas e invisiveis para quem consulta.

### Por que a quantidade nao e um detalhe

Sem Crawler, particao no S3 e particao no catalogo sao duas coisas separadas. O
gerador produz trinta objetos, um por dia, em `raw/corridas/dt=AAAA-MM-DD/`. O
S3 guarda os trinta. O Athena so enxerga os que estao registrados no Glue Data
Catalog, e com a tabela declarada a mao (`projection.enabled: false`) o registro
so acontece se eu escrever o recurso `AWS::Glue::Partition` correspondente.

O efeito pratico: as vinte e sete particoes que eu nao declarei existem, ocupam
espaco, aparecem na fatura do S3, e para quem faz a pergunta elas simplesmente
nao existem. Nao ha erro, nao ha aviso, nao ha linha de log. A consulta responde
normalmente, so que sobre um pedaco do dado.

### O que a pergunta de negocio exige

A pergunta que motivou o lake e "quais bairros do Recife concentram corridas na
madrugada, e desde quando". A segunda metade dela, o "desde quando", e uma
pergunta sobre historico: ela quer saber a partir de que momento o padrao
aparece.

Com tres particoes eu tenho tres dias de janela. Tres dias nao respondem "desde
quando", respondem "anteontem, ontem e hoje". Quem consultar essa tabela vai
receber um resultado tecnicamente correto para uma pergunta que nao e a que
foi feita.

Isso e uma limitacao real da minha entrega, e prefiro registra-la aqui a fingir
que tres particoes atendem o caso de uso.

### O que a quantidade faz com o custo, e o que ela nao faz

Aqui e importante separar duas coisas que costumam ser confundidas.

O que derruba o custo de uma consulta e o filtro de particao, nao a quantidade
de particoes declaradas. Uma consulta com `WHERE dt = '2026-08-22'` le um unico
objeto, cerca de 3.921.495 bytes, e isso vale igual se eu tiver declarado tres
particoes ou trinta. O tamanho da particao nao muda porque outras foram
registradas.

O que a quantidade muda e o tamanho da consulta sem filtro, e e por ai que ela
toca a DECISAO 05. Com tres particoes declaradas, um `SELECT count(*) FROM
corridas` sem `WHERE` varre aproximadamente 11.765.561 bytes (as tres somadas).
Com trinta, varreria os 117.655.606 bytes do lake inteiro.

Isso importa porque o teto de bytes precisa caber entre a consulta estreita e a
consulta larga, e a AWS impoe um piso de 10.485.760 bytes para
`BytesScannedCutoffPerQuery`. Com tres particoes, a janela util do teto vai de
10.485.760 a 11.765.560 bytes, cerca de 1,28 MB de folga, aproximadamente 11%.
E uma margem estreita: basta uma particao sair menor que a media para a consulta
larga passar por baixo do teto, e nesse caso o freio deixa de tocar exatamente
na consulta que ele existe para barrar.

Declarar mais particoes alargaria essa janela. Com cinco, a consulta larga
varreria cerca de 19.609.268 bytes e o teto teria quase 9 MB de folga. A
decisao de ficar em tres, portanto, e a decisao de trabalhar com a margem mais
apertada que o exercicio permite.

### O custo que cresce com a quantidade

O que aumenta com cada particao declarada e trabalho manual. Cada uma e um
recurso `AWS::Glue::Partition` escrito a mao no template, com o `Location`
apontando para a chave exata do objeto no S3. Se o `Location` nao bater com a
chave, o Athena devolve zero linha e nenhum erro: a resposta parece certa e nao
e, e nada no caminho sinaliza a diferenca.

E ha um problema que nao se resolve escrevendo mais recursos. Amanha o gerador
produz um dia novo. Esse dia chega ao S3 pelo `aws s3 sync` e nao chega ao
catalogo, porque neste template nao existe nenhum processo que registre
particao: o registro so acontece quando alguem edita o arquivo e roda o deploy
outra vez. No dia seguinte, a particao que hoje e a mais recente passa a ser a
de ontem, e o catalogo para de refletir o que esta no armazenamento ate que
esse deploy aconteca.

Declarar particao a mao, portanto, nao e um trabalho que se faz uma vez. E um
trabalho que se repete a cada dia novo, indefinidamente, ou a tabela envelhece
em silencio. Subir de tres para trinta particoes nao resolve isso: apenas adia
o mesmo problema em vinte e sete dias.

### O resumo do trade-off

| Eixo | Poucas particoes (3) | Muitas particoes (30) |
| --- | --- | --- |
| Pergunta "desde quando" | nao responde | responde |
| Custo da consulta filtrada | ~3,92 MB | ~3,92 MB (igual) |
| Consulta sem filtro | ~11,77 MB | ~117,66 MB |
| Folga do teto de bytes | ~1,28 MB (11%) | ~107 MB |
| Linhas de template a manter | 3 blocos | 30 blocos |
| Particao de amanha | ninguem registra | ninguem registra (igual) |

A ultima linha e a que importa mais: o problema de manutencao nao melhora com
mais particoes declaradas, so fica maior. Ele e estrutural, e vem de ter tirado
o processo que fazia o registro.

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
