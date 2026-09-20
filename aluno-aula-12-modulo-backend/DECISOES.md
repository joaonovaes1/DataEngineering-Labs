# DECISOES.md, Exercício 03 (Aula 12)

Refatoração da stack plana em módulo + backend remoto + workspace, sem recriar
recurso. `sufixo = jmnfa`, conta 325583868777, região us-east-1.

---

## DECISÃO 01, a fronteira do módulo

Entrou no módulo só o que **cria** coisa: os seis `resource`. Ficou na raiz o que
**negocia com o mundo de fora**, ou seja, `provider` e `default_tags`, as variáveis
entrada com sua `validation`, o `backend`, e os cinco outputs de contrato. O
critério que usei é "quem é o interlocutor": o operador fala com a raiz, então a
validação do sufixo mora lá, senão o erro apareceria uma camada abaixo de onde o
valor foi digitado.

Duas consequências práticas. Primeira, o módulo não declara `provider`, herdando
o da raiz, o que o torna reutilizável em outra região sem edição. Segunda, o
bucket de estado (`eda-tfstate-grupo01`) ficou **fora** do Terraform, criado à
mão. Não é preguiça, é ovo e galinha: o bucket que guarda o estado não pode ser
criado pela stack cujo estado ele guarda, porque no primeiro `init` ele ainda não
existe. Infraestrutura de bootstrap vive fora do ciclo que ela sustenta.

Único output que não passa pelo módulo: `teto_bytes`. Ele é variável de entrada,
não resultado de recurso, e a raiz já o tem em mãos. Fazer a volta raiz, módulo,
raiz seria cerimônia sem ganho.

---

## DECISÃO 02, mover o estado

Usei `terraform state mv`, seis vezes, e não `moved {}`. A rubrica aceita os dois,
mas eles resolvem problemas diferentes. O `moved {}` é declarativo e fica no código
para sempre, servindo a quem **publica** um módulo e precisa que o rename seja
transparente para todos os consumidores. O `state mv` é imperativo, acontece uma vez
e não deixa rastro. Como esta refatoração é interna e tem exatamente um operador
(eu), o rastro permanente de seis blocos `moved` seria dívida de leitura sem
benefício.

O que aprendi tem número. O `serial` do estado foi de **7 para 13**, ou seja, seis
escritas, e **nenhum** dos seis comandos emitiu `Refreshing` ou esperou pela
rede. Os IDs antes e depois são os mesmos: `eda-a12-jmnfa-lake`,
`325583868777:eda_a12_jmnfa:corridas`. O `state mv` reescreve o mapa, e o território
nem fica sabendo.

Aprendi também por acidente. Colei os seis comandos de uma vez e o terminal comeu
a primeira linha (`^[[200~terraform: command not found`). Cinco moveram, um ficou.
O `state list` mostrou `aws_s3_bucket.lake` sozinho na raiz enquanto os outros
cinco já estavam em `module.lake.*`, que é o modo de falha nº 3 da rubrica, ao vivo.
Um `plan` ali teria dito `1 to add, 1 to destroy`, e num `plan` de quatrocentas
linhas essa única linha passa batido. Daí a lição operacional: **conferir com
`terraform state list`, não com leitura do `plan`.** A lista tem seis linhas, o
`plan` tem quatrocentas.

---

## DECISÃO 03, workspace × pasta

Workspace, com a stack migrada permanecendo no `default`.

Por que workspace e não pasta: pasta duplica o código, e código duplicado
diverge. A stack é **a mesma** em dev e em prod, e o que muda é o valor das
variáveis, não a forma. Workspace separa estado sem separar código, que é
exatamente a fronteira do problema. A pasta se justificaria se os ambientes
tivessem topologias diferentes, o que não é o caso.

Por que o `default`: porque migrar é diferente de nomear. A stack já existia,
criada no workspace `default`, e mover o estado para um workspace `dev` mudaria a
chave no S3. Pior, se o código lesse `terraform.workspace` para compor o `sufixo`,
mudaria os nomes de todos os recursos, recriando tudo. Workspace novo é para
**ambiente novo**, não para rebatizar o que já roda. Criei o `dev` vazio e voltei
imediatamente com `workspace select default`.

O backend deixa isso visível. Com `workspace_key_prefix = "eda-a12"`, o bucket
ficou assim:

```
aula12/jmnfa/terraform.tfstate                12628 bytes  ← default, 6 recursos
eda-a12/dev/aula12/jmnfa/terraform.tfstate      181 bytes  ← dev, vazio
```

Os 181 bytes são um estado vazio, e é esse objeto que torna o workspace
*visível*. Com backend S3, `workspace list` enumera prefixos no bucket, não uma
lista à parte.

Nota sobre nomes: o bucket de estado é **do grupo** (`eda-tfstate-grupo01`,
seguindo o padrão dos outros seis grupos da conta), mas o `sufixo` dos recursos é
**pessoal** (`jmnfa`). Tem que ser, porque nome de bucket S3 é global, então dois colegas
do mesmo grupo com `sufixo = grupo01` colidiriam em `BucketAlreadyExists`. A
separação entre colegas vai no `key` (`aula12/jmnfa/`), não no nome do bucket.

---

## DECISÃO 04, o que o plan limpo prova, e o que não prova

**Prova** que código e estado concordam sobre *quais recursos existem e com quais
atributos gerenciados*. Especificamente: prova que a refatoração não trocou
nenhum endereço por um recurso novo, porque os seis IDs do estado são os seis IDs
que o `refresh` encontrou na AWS.

**Não prova** que a AWS está como eu imagino. O `plan` compara três coisas e só
enxerga o que o código menciona. Duas lacunas concretas, ambas visíveis nesta
stack.

Primeira, atributos não declarados. O `refresh` do Passo 3 trouxe
`server_side_encryption_configuration` com `AES256`, um `grant` de
`FULL_CONTROL`, e `engine_version` com `Athena engine version 3`. Nada disso está
no meu código, são defaults que a AWS aplicou sozinha. Se alguém mudar a
criptografia do bucket pelo console, o `plan` continua limpo, porque não há nada
no código para discordar.

Segunda, o próprio `refresh` é um retrato do instante. `No changes` às 13h30 não
diz nada sobre 13h31. Drift é uma propriedade do tempo, e `plan` é uma foto.

E há um terceiro limite, mais sutil. O `plan` limpo prova que nada **vai** ser
recriado, não que nada **foi** recriado. Se eu tivesse aplicado antes do
`state mv`, a stack seria recriada e o `plan` seguinte estaria igualmente limpo,
só que sobre recursos novos, com IDs novos. O `plan` limpo só tem valor como prova de
refatoração **junto com** a evidência de que os IDs são os mesmos de antes.

---

## DECISÃO 05, a ordem

Se eu tivesse dado `apply` no Passo 3, o `plan` já dizia o que ia acontecer:
`6 to add, 0 to change, 6 to destroy`, com o motivo explícito em cada bloco,
`(because aws_s3_bucket.lake is not in configuration)`. O Terraform não estava
confuso, estava certo dentro do que sabe. Ele compara conjuntos de **endereços**,
e depois do Passo 2 os dois conjuntos eram disjuntos, porque seis endereços
sumiram do código e seis apareceram. Apagar e criar é a única conclusão possível a partir
dessa premissa.

O estrago teria três camadas. Perda de dados, porque `force_destroy = true` nos
dois buckets faria o `raw/corridas/` ir junto, sem resistência. Stack meio
quebrada, porque o `plan` queria destruir e recriar os buckets com o mesmo nome
(`- bucket = "eda-a12-jmnfa-lake" -> null` seguido de
`+ bucket = "eda-a12-jmnfa-lake"`), e o S3 não libera o nome imediatamente após o
delete, então o `apply` provavelmente falharia no meio, com metade dos recursos
destruídos e o resto não criado. Perda do histórico, porque os IDs e ARNs seriam
outros, e qualquer coisa apontando para eles, uma query salva no Athena ou um job
do Glue, quebraria em silêncio.

A regra que extraio disso é uma só, **estado antes de infraestrutura.** Toda refatoração
que muda endereço tem uma janela em que o código e o estado discordam, e nessa
janela `apply` é destrutivo por definição. O `state mv` fecha a janela sem tocar
na nuvem. A ordem não é preferência de estilo, é a diferença entre reorganizar e
reconstruir.
