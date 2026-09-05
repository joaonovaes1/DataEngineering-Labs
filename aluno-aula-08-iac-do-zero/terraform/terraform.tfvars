# Copie este arquivo para terraform.tfvars e preencha.
#   cp terraform.tfvars.example terraform.tfvars

sufixo = "jmnfa"        # so minusculas, numeros e hifen

# DECISAO 05 — o teto que voce MEDIU (nao copie do lab).
# Medido: larga (7 particoes, SELECT count(*) FROM corridas) = 23.859.750 bytes.
# estreita (WHERE dt=hoje) = 3.408.166 bytes. Piso da AWS = 10.485.760.
# Escolhido o piso: maxima margem contra a larga, folga grande sobre a estreita.
teto_bytes = 10485760

# DECISAO 04 — os dias que voce vai registrar como particao (>= 3, incluindo hoje).
# Janela movel de 7 dias terminando hoje; 2026-08-28 fica de fora de proposito.
dias_particao = ["2026-08-29", "2026-08-30", "2026-08-31", "2026-09-01", "2026-09-02", "2026-09-03", "2026-09-04"]
