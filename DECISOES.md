# Decisões do Exercício 01

Lake mínimo com o schema declarado, sem Crawler.

| | |
| --- | --- |
| Autor | João Marcelo (jmnfa@cesar.school) |
| Login e sufixo dos recursos | `eda-grupo01` |
| Conta | 325583868777, região us-east-1 |

Cada decisão abaixo está marcada no `infra/template.yaml`, no ponto do arquivo em
que ela acontece. Todas as medições citadas foram feitas sobre os 518.400 eventos
gerados e sobre a stack em execução, antes do destroy.

---

## DECISÃO 01: o tipo da coluna `valor`

**Escolhi `string`.**

### O que medi

Abri os 518.400 eventos e classifiquei o campo `valor` por tipo JSON:

| Formato emitido pelo produtor | Eventos | Fatia |
| --- | --- | --- |
| número, por exemplo `9.8` | 510.712 | 98,52% |
| texto com vírgula, por exemplo `"9,49"` | 7.688 | 1,48% |

O que interessa não é o percentual de linhas, e sim a receita que elas carregam:

```
faturamento nos eventos numéricos:  R$ 8.923.930,64
faturamento nos eventos em texto:   R$   134.749,67
total:                              R$ 9.058.680,31
```

Os 1,48% de linhas correspondem a 1,49% da receita, R$ 134.749,67.

### Por que descartei `double` e `decimal(10,2)`

Com `double`, o texto `"9,49"` não converte e o campo recebe `NULL`. A linha
continua existindo e o `count(*)` continua correto, mas o valor desaparece. Um
`SELECT sum(valor)` devolveria R$ 8.923.930,64 sem qualquer sinal de que faltam
R$ 134.749,67. A resposta tem a forma de uma resposta correta.

Com `decimal(10,2)` acontece o mesmo. Registro isso porque a intuição sugere o
contrário: um tipo mais estrito deveria recusar o dado ruim de forma ruidosa.
Com o JSON SerDe isso não ocorre, e `"9,49"` vira `NULL` exatamente como viraria
contra `double`. Paga-se a rigidez do tipo decimal sem receber o alarme em troca.

### Por que escolhi `string`

Porque é a única das três opções em que o dado sobrevive até a consulta.

Declarar um tipo forte transforma a leitura em uma conversão obrigatória e
silenciosa: o que não couber é descartado antes que alguém veja. Com `string`, a
conversão deixa de ser automática e passa a ser escrita:

```sql
SELECT sum(CAST(replace(valor, ',', '.') AS double))
FROM corridas WHERE dt = '2026-08-22';
```

O `replace` está ali porque medi a vírgula e sei que ela existe. Quem lê a
consulta enxerga o tratamento e pode discordar dele.

E o problema passa a ser contável. Confirmei isso na stack em execução:

```sql
SELECT count(*) FROM corridas
WHERE dt = '2026-08-22' AND regexp_like(valor, ',');
```

A consulta devolveu 245 registros naquele dia. Com `double` essa pergunta seria
impossível, porque os registros já teriam perdido a característica que os
identifica. Restaria `WHERE valor IS NULL`, que conta os afetados mas não separa
"o produtor não enviou valor" de "o produtor enviou um valor que não soube ler",
e não permite recuperar nenhum deles.

### O que essa escolha custa

O preço é real. Toda consulta que faz aritmética sobre `valor` fica mais longa e
mais sujeita a erro. Um analista que escrever `SELECT sum(valor)` recebe erro de
tipo. Ferramentas de BI que inferem tipo pelo catálogo tratarão a coluna como
categoria em vez de medida.

`string` não resolve o problema, apenas o desloca: sai da leitura, onde ninguém o
vê, e entra na consulta, onde fica visível e alguém precisa tratá-lo. Aceitei
essa troca. Prefiro uma coluna incômoda que obriga a decisão a ser explícita a
uma coluna confortável que descarta R$ 134,7 mil sem avisar.

Nenhum dos três tipos corrige a origem. Enquanto o produtor emitir `"9,49"`,
alguém pagará por isso, seja em valor descartado, seja em conversão repetida. O
tipo declarado decide apenas quem paga e se a conta aparece.

---

## DECISÃO 02: o tipo das colunas de tempo

**Escolhi `timestamp`, para `data_corrida` e para `fim`.**

### A hipótese que eu tinha antes de testar

O produtor emite as duas colunas em ISO 8601 com sufixo de fuso:

```
data_corrida: 2026-08-22T00:47:19Z
```

Verifiquei 51.840 linhas e todas seguem esse formato, sem exceção.

O tipo `timestamp` do Hive documenta aceitar `yyyy-MM-dd HH:mm:ss`, com espaço
separando data e hora e sem sufixo. O dado traz um `T` no lugar do espaço e um
`Z` ao final. Minha hipótese era que nenhuma das duas colunas converteria e que
as 17.280 linhas do dia viriam nulas.

### O que o SELECT devolveu

Subi a stack com `timestamp` declarado e contei:

```sql
SELECT count(*) AS total, count(data_corrida) AS com_data, count(fim) AS com_fim
FROM corridas WHERE dt = '2026-08-22';
```

| total | com_data | com_fim |
| --- | --- | --- |
| 17.280 | 17.280 | 17.280 |

Zero nulos. **Minha hipótese estava errada.**

Comparando três registros na tabela e no arquivo bruto:

| corrida_id | no S3 | na tabela |
| --- | --- | --- |
| c-00501121 | `2026-08-22T00:47:19Z` | `2026-08-22 00:47:19.000` |
| c-00501122 | `2026-08-22T00:58:21Z` | `2026-08-22 00:58:21.000` |

O `org.openx.data.jsonserde.JsonSerDe` aceita ISO 8601 com `T` e com `Z`, e não
apenas o formato documentado pelo tipo. Deduzi a incompatibilidade da
documentação, e o SerDe comporta-se de maneira mais permissiva que ela.

### O que a conversão faz com o fuso

O horário de parede é idêntico nos dois lados: `00:47:19` entra e `00:47:19` sai.
O `Z` foi descartado, não convertido.

Para este lake isso é indiferente, porque toda a origem emite em UTC. Registro
como risco: se um produtor passar a enviar `-03:00` em vez de `Z`, o valor será
lido como horário de parede sem conversão, e a diferença de três horas entrará na
tabela sem nenhum sinal. Não testei esse caso, porque não há dado assim hoje.

### O que medi do lado de `string`

Para não supor também deste lado, criei uma tabela sobre o mesmo objeto do S3 com
as duas colunas como `string`. O texto chega exatamente como foi escrito, sem
perda. Mas a pergunta de negócio deixa de compilar:

```sql
SELECT count(*) FROM corridas WHERE hour(data_corrida) BETWEEN 0 AND 4;
```

```
FUNCTION_NOT_FOUND: Unexpected parameters (varchar) for function hour.
```

Não é resultado errado, é recusa. Para responder o mesmo, é preciso converter
dentro da consulta:

```sql
WHERE hour(from_iso8601_timestamp(data_corrida)) BETWEEN 0 AND 4
```

Isso funciona e devolveu 1.274 corridas na madrugada. O custo é que a conversão
passa a ser obrigatória em toda pergunta que envolva tempo.

| | `timestamp` | `string` |
| --- | --- | --- |
| Linhas convertidas | 17.280 de 17.280 | não se aplica, é texto cru |
| Dado perdido | nenhum | nenhum |
| `hour(data_corrida)` | funciona | `FUNCTION_NOT_FOUND` |
| Pergunta da madrugada | direta | exige `from_iso8601_timestamp` |

Os dois preservam o dado. `timestamp` preserva e ainda entrega o tipo pronto para
a pergunta que motivou o lake, que é sobre corridas na madrugada:

```sql
SELECT bairro, count(*) AS corridas FROM corridas
WHERE dt = '2026-08-22' AND hour(data_corrida) BETWEEN 0 AND 4
GROUP BY bairro ORDER BY 2 DESC LIMIT 5;
```

| bairro | corridas |
| --- | --- |
| Boa Viagem | 252 |
| Pina | 96 |
| Recife Antigo | 77 |

### O critério comum às duas primeiras decisões

As conclusões foram opostas, mas o critério foi o mesmo: **declarar o tipo mais
forte que o dado real suporta sem perda**. Em `valor` isso é `string`, porque o
dado não suporta `double`. Em `data_corrida` e `fim` isso é `timestamp`, porque o
dado suporta. O que mudou entre os dois casos não foi o princípio, foi a medição.

Se eu tivesse declarado `string` sem testar, teria entregue uma coluna de texto
onde cabia um tipo temporal, com uma justificativa que citaria uma
incompatibilidade inexistente. O teste custou um deploy e três consultas.

---

## DECISÃO 03: `ignore.malformed.json`

**Escolhi `"true"`.**

### O dado de hoje não decide

Antes de escolher, verifiquei se a questão sequer se manifesta no lake atual. Li
as 518.400 linhas com um parser de JSON e contei as falhas: nenhuma. Todas são
JSON válido.

Com o dado que existe hoje, `"true"` e `"false"` produzem resultados idênticos em
qualquer consulta. A decisão não é sobre este dado, e sim sobre o dia em que o
produtor emitir uma linha truncada.

### O teste que forcei

Subi um objeto com quatro linhas, sendo a terceira um JSON com a chave sem
fechar, e criei duas tabelas idênticas sobre ele, diferindo apenas neste
parâmetro.

| Consulta | `"false"` | `"true"` |
| --- | --- | --- |
| `SELECT count(*)` | 4 | 4 |
| `SELECT corrida_id, bairro` | falha | 4 linhas |

Com `"false"`, a consulta que projeta colunas termina em `FAILED`:

```
HIVE_CURSOR_ERROR: Failed to read file at s3://.../parte-0001.json
```

Com `"true"`, a mesma consulta responde, e a linha quebrada aparece como registro
com todos os campos nulos: `total = 4`, `válidas = 3`, `fantasmas = 1`.

### Dois achados que mudaram minha leitura de `"false"`

**`"false"` não falha sempre.** O `count(*)` passou nas duas tabelas. Contar
linhas não obriga o SerDe a desserializar os campos, então o dado ruim nunca é
tocado. Apenas a consulta que projeta coluna quebra. Um painel que só conta
corridas por dia continuaria verde por semanas com um arquivo corrompido no lake.
O alarme depende do formato da pergunta, e não da existência do problema.

**A mensagem aponta o arquivo, não a linha.** Num objeto de 3,9 MB com 17.280
linhas, localizar a linha ruim é trabalho manual, feito enquanto a tabela inteira
está indisponível para todos.

### Por que escolhi `"true"`

Porque o custo de `"false"` recai sobre quem não tem relação com o problema, e o
benefício dele não é confiável. Uma única linha ruim tornaria a tabela ilegível
para todas as consultas que projetam coluna, de todos os usuários, até que alguém
editasse o objeto no S3. O produtor erra e os analistas pagam, com uma
indisponibilidade que a mensagem de erro não explica.

É a mesma orientação da DECISÃO 01, aplicada a outro ponto do caminho: manter o
sistema respondendo e tornar o defeito contável, em vez de interromper a leitura.

### O que essa escolha custa

A linha quebrada vira uma linha fantasma. Ela entra no `count(*)`, inflando a
contagem do dia, e todos os seus campos são nulos, o que faz o defeito parecer
"dado faltando" em vez de "dado corrompido". São dois problemas distintos que
`"true"` torna indistinguíveis à primeira vista.

Por isso a escolha só se sustenta acompanhada de uma consulta de vigilância:

```sql
SELECT dt, count(*) AS total, count(corrida_id) AS válidas,
       count(*) - count(corrida_id) AS fantasmas
FROM corridas GROUP BY dt
HAVING count(*) - count(corrida_id) > 0;
```

Qualquer linha devolvida é um objeto com JSON quebrado. Hoje ela retorna vazia.

Registro a limitação: essa consulta não roda sozinha. Não há nada neste template
que a execute nem que avise alguém se ela deixar de vir vazia. `"true"` transfere
a detecção do motor de consulta para uma rotina que ainda não existe. `"false"`
tampouco resolveria isso, apenas trocaria a detecção tardia por uma
indisponibilidade imediata, e ainda assim só em algumas consultas.

---

## DECISÃO 04: quantas partições declarar

**Declarei três partições: anteontem, ontem e hoje.** As outras vinte e sete
permanecem no S3, pagas e invisíveis para quem consulta.

### Duas perguntas distintas

Há duas questões dentro desta decisão, e confundi-las leva à conclusão errada. A
primeira é de que tamanho é cada fatia do dado. A segunda é quantas fatias eu
registro no catálogo.

**O tamanho da fatia** determina o custo de uma consulta filtrada, porque o
Athena abre a fatia inteira em que o filtro cai:

| Fatiamento | Partições | Uma consulta de um dia lê |
| --- | --- | --- |
| nenhum | 0 | 117.655.606 bytes |
| por mês | 1 | 117.655.606 bytes |
| por dia | 30 | 3.921.495 bytes |

Fatiar mais fino barateia, e barateia muito. Essa parte, porém, não é decisão
deste template: o gerador já grava uma pasta por dia, e eu herdo a granularidade.

**O número de fatias registradas** é o que de fato decido, e o efeito é outro:

| Partições registradas | `WHERE dt = 'hoje'` lê | `SELECT count(*)` sem filtro lê |
| --- | --- | --- |
| 3 | 3.921.495 bytes | 11.765.273 bytes |
| 30 | 3.921.495 bytes | 117.655.606 bytes |

A coluna do meio não se move. Declarar a partição de doze de julho não barateia a
consulta de hoje, que continua abrindo um arquivo só. O que cresce é a consulta
sem filtro. Quem reduz o custo é o filtro `WHERE dt =` somado à granularidade da
fatia, e não a quantidade de partições catalogadas.

### Registrar poucas partições não é economia

Uma pergunta por um dia não declarado, como `WHERE dt = '2026-07-15'`, devolve
zero linhas e quase não cobra, porque quase nada foi lido. Parece economia, mas
não é. Quem perguntou recebeu resposta vazia sem qualquer sinal de que o dia
existe no S3 e apenas não está catalogado. Não há erro, aviso nem log.

O barato não veio de ler menos para chegar à mesma resposta. Veio de não
responder. São vinte e sete dias de corrida armazenados, presentes na fatura do
S3, e inexistentes para qualquer pergunta feita a essa tabela.

### O que a pergunta de negócio exige

A pergunta que motivou o lake é "quais bairros do Recife concentram corridas na
madrugada, e desde quando". O "desde quando" é uma pergunta sobre histórico.

Três partições dão três dias de janela, o que não responde "desde quando".
Registro isso como limitação real da entrega, em vez de sustentar que três dias
atendem ao caso de uso.

### Por que fiquei em três

O `deploy.sh` calcula exatamente três datas e passa três overrides fixos ao
template. Declarar uma quarta partição exigiria alterar o `deploy.sh` além do
`template.yaml`, e o `deploy.sh` não faz parte do que entrego. Quem recebesse
esta entrega não conseguiria reproduzir a stack, porque faltaria a peça que
informa as datas adicionais.

A escolha, portanto, não foi entre três e trinta. Foi entre três partições com
ferramental coerente, ou mais partições e uma entrega que não se reproduz.

### O custo que cresce a cada partição

Cada partição é um recurso escrito manualmente, com o `Location` apontando para a
chave exata do objeto. Se o `Location` não corresponder à chave, o Athena devolve
zero linhas e nenhum erro.

E há um problema que não se resolve escrevendo mais recursos. Amanhã o gerador
produz um dia novo, que chega ao S3 pelo `aws s3 sync` e não chega ao catálogo,
porque neste template não existe processo que registre partição. O registro só
ocorre quando alguém edita o arquivo e executa o deploy outra vez.

Declarar partição manualmente não é trabalho que se faça uma vez. Repete-se a
cada dia novo, indefinidamente, ou a tabela envelhece em silêncio. Subir de três
para trinta não resolve isso: apenas adia o mesmo problema em vinte e sete dias.

---

## DECISÃO 05: o teto de bytes por consulta

**Escolhi `10485760` bytes, dez mebibytes**, que é o menor valor aceito pela AWS
para `BytesScannedCutoffPerQuery`.

### O que o teto faz

O Athena cobra por byte lido, e não por tempo de execução. Ele não sabe o preço
de uma consulta antes de executá-la: começa a ler e vai contando. O teto é o
ponto em que ele desiste. Ultrapassado o limite, a execução é abortada e não
devolve resultado, nem parcial. Com `EnforceWorkGroupConfiguration: true`,
ninguém contorna isso na hora da consulta.

### O que medi

Somei os bytes dos três objetos que o `deploy.sh` declara:

| Partição | Bytes |
| --- | --- |
| `dt=2026-08-20` | 3.921.456 |
| `dt=2026-08-21` | 3.922.322 |
| `dt=2026-08-22` | 3.921.495 |
| **soma** | **11.765.273** |

Disso saem os dois limites: a consulta filtrada lê 3.921.495 bytes e precisa
passar; a consulta sem filtro lê 11.765.273 bytes e precisa ser barrada. O teto
tem de ficar entre os dois.

### A restrição que estreita a faixa

A AWS não aceita `BytesScannedCutoffPerQuery` abaixo de 10.485.760 bytes. Isso
não vem do enunciado: é limite do próprio serviço.

```
3.921.495 ------- 10.485.760 ======== 11.765.272 ------->
consulta filtrada   piso da AWS       teto máximo útil
                        |__ faixa real __|
                           1.279.513 bytes
```

Restam 1.279.513 bytes de manobra, cerca de 1,22 MiB.

### Por que escolhi o extremo inferior

Dentro da faixa, todo valor funciona. Eles diferem na folga até a consulta que
precisa ser barrada:

| Teto | Distância até a consulta sem filtro |
| --- | --- |
| 10.485.760 | 1.279.513 bytes |
| 11.000.000 | 765.273 bytes |
| 11.700.000 | 65.273 bytes |

O risco é assimétrico. Do lado inferior, mesmo no piso o teto fica 2,67 vezes
acima da consulta filtrada, que passa com folga larga e sem risco de ser barrada
indevidamente. Do lado superior, cada aproximação encurta a margem contra a
consulta que precisa morrer. Como o risco está concentrado de um lado, escolhi o
extremo oposto a ele.

### O resultado observado

Na stack em execução, a consulta sem filtro foi interrompida em exatamente
10.485.760 bytes, com o motivo `Bytes scanned limit was exceeded` no histórico do
workgroup, e a consulta filtrada respondeu lendo 3.921.495 bytes. O comportamento
pretendido ocorreu.

### O que este número admite sobre si mesmo

Este teto não foi escolhido, foi espremido. A AWS pressiona por baixo com o piso
de 10 MiB e as três partições pressionam por cima com 11,77 MB. Restou 1,2 MB, e
dentro desse espaço a única decisão possível era de que lado encostar.

Duas consequências valem mais que o número em si.

A primeira: o teto está atrelado à quantidade de partições declaradas, e não ao
tamanho do lake. Se eu declarasse as trinta, a consulta sem filtro varreria
117.655.606 bytes e o mesmo teto continuaria funcionando com folga dez vezes
maior. A margem estreita é efeito da DECISÃO 04, não do Athena.

A segunda: o valor é absoluto em bytes, e não uma fração do total. Ele protege
contra uma consulta larga em uma tabela pequena, mas não escala junto se a tabela
crescer. Um teto proporcional não existe nesta configuração: se o lake crescer, o
número precisa ser revisto manualmente, assim como as partições.
