# Rubrica — Exercício 03 (Aula 12)

Refatorar a stack plana em **módulo + backend remoto + workspace**, com **`plan`
limpo**. Pública desde a Aula 03 — não muda.

| # | Critério | Como é verificado | Peso |
| --- | --- | --- | --- |
| 0 | **Módulo + backend remoto + workspace.** Existe `module "..."` + pasta `modules/`, `backend "s3"`, e um workspace | `verifica.sh` | **elimina** |
| 1 | **`plan` LIMPO — `0 to add, 0 to change, 0 to destroy`** | `verifica.sh` (`plan -detailed-exitcode`) | 30% |
| 2 | Estado no backend remoto (não há `tfstate` local com recursos) | `verifica.sh` | 15% |
| 3 | Um workspace nomeado em uso (ou código workspace-aware) | `verifica.sh` | 10% |
| 4 | Os cinco outputs de contrato preservados | `verifica.sh` · `output` | 10% |
| 5 | `destroy` limpo, sem recurso órfão | `verifica.sh --pos-destroy` | 15% |
| 6 | `DECISOES.md`: uma justificativa por decisão (01 a 05) | leitura | 20% |

**O critério 1 é o exercício** (30%, o maior peso). Refatorar que recria não é
refatorar. Um `plan` que quer mudar qualquer coisa é FALHA no item.

**Os cinco outputs de contrato** (preservar na refatoração): `bucket_name` ·
`database_name` · `table_name` · `workgroup_name` · `teto_bytes`.

**O que NÃO conta:** elegância do HCL; ter usado `state mv` em vez de `moved {}`
(os dois valem); número de arquivos do módulo.

> Uma decisão **diferente** do gabarito, **bem justificada**, vale 10.
> Uma decisão **igual** ao gabarito, **sem justificativa**, não passa de 8.

**O que mais reprova**

1. **Aplicar antes do `state mv`** — destrói e recria; pode deixar a stack meio quebrada.
2. **Renomear um recurso** ao movê-lo para o módulo — vira recriação; `plan` não fica limpo.
3. **Esquecer um `state mv`** — sobra um recurso no `plan`.
4. Comitar `terraform.tfstate`, `.terraform/` ou `backend.hcl` com o nome da conta.

**Entrega.** PR com a pasta refatorada, o `DECISOES.md` e a saída do `verifica.sh`
colada. Rode o script antes de entregar: **a nota não é surpresa.** Fora do prazo,
nota inicial **8,0**.

> **v2 — sem nota própria.** Este exercício entrega a stack **módulo + backend +
> workspace** que compõe a **Parte 1 do projeto** (AV1, Aula 16). O `verifica.sh`
> vale como aceite; a nota cai no projeto. O backend é o **compartilhado** da
> disciplina — não é deste exercício e sobrevive ao `destroy`.
