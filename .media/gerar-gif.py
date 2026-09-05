from PIL import Image, ImageDraw, ImageFont

W, H = 1200, 627
FUNDO      = (13, 17, 23)
BARRA      = (22, 27, 34)
BORDA      = (48, 54, 61)
TEXTO      = (201, 209, 217)
CINZA      = (110, 118, 129)
VERDE      = (63, 185, 80)
AMBAR      = (210, 153, 34)
AZUL       = (88, 166, 255)
VERMELHO   = (248, 81, 73)

MONO   = "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"
NEGRITO= "/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf"
f      = ImageFont.truetype(MONO, 25)
f_bold = ImageFont.truetype(NEGRITO, 25)
f_tit  = ImageFont.truetype(MONO, 18)

MARGEM_X, TOPO_BARRA, TOPO_TEXTO, ALTURA_LINHA = 40, 54, 96, 38

def cor_da_linha(linha):
    if linha.startswith("$"):        return VERDE, f_bold
    if linha.startswith("DONE"):     return VERDE, f
    if linha.startswith("PENDING"):  return AMBAR, f
    if linha.startswith("MANUAL"):   return CINZA, f
    if "FINISHED" in linha:          return VERDE, f_bold
    if linha.startswith("  "):       return CINZA, f
    if linha.startswith("2026-"):    return TEXTO, f
    return TEXTO, f

def desenhar(linhas, cursor=True):
    img = Image.new("RGB", (W, H), FUNDO)
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, W, TOPO_BARRA], fill=BARRA)
    d.line([0, TOPO_BARRA, W, TOPO_BARRA], fill=BORDA)
    for i, c in enumerate([(255,95,86), (255,189,46), (39,201,63)]):
        d.ellipse([MARGEM_X + i*24, 20, MARGEM_X + i*24 + 13, 33], fill=c)
        
    d.text((MARGEM_X + 100, 17), "agent-ledger-loop", font=f_tit, fill=CINZA)
    y = TOPO_TEXTO
    for linha in linhas:
        cor, fonte = cor_da_linha(linha)
        # timestamp do log em cinza, resto na cor da linha
        if linha.startswith("2026-") and " " in linha:
            marca, resto = linha.split(" ", 1)
            d.text((MARGEM_X, y), marca, font=f, fill=CINZA)
            largura = d.textlength(marca + " ", font=f)
            cor_resto = AZUL if resto.startswith("round") else TEXTO
            if resto.startswith("remaining: 0"): cor_resto = VERDE
            d.text((MARGEM_X + largura, y), resto, font=f, fill=cor_resto)
        else:
            d.text((MARGEM_X, y), linha, font=fonte, fill=cor)
        y += ALTURA_LINHA
    if cursor and y < H - 30:
        d.rectangle([MARGEM_X, y + 4, MARGEM_X + 11, y + 20], fill=TEXTO)
    return img

# --- o roteiro. Toda saida abaixo e o formato real do repositorio. ---
ROTEIRO = [
 (["$ ./ledger.sh show"], 12),
 (["$ ./ledger.sh show",
   "DONE     P0    project-skeleton-and-gate     a1b2c3d",
   "PENDING  P1    first-real-phase",
   "PENDING  P2    second-phase",
   "MANUAL   P9    production-cutover"], 26),
 (["$ ./ledger.sh show",
   "DONE     P0    project-skeleton-and-gate     a1b2c3d",
   "PENDING  P1    first-real-phase",
   "PENDING  P2    second-phase",
   "MANUAL   P9    production-cutover",
   "",
   "$ ./loop.sh"], 14),
 (["$ ./ledger.sh show",
   "DONE     P0    project-skeleton-and-gate     a1b2c3d",
   "PENDING  P1    first-real-phase",
   "PENDING  P2    second-phase",
   "MANUAL   P9    production-cutover",
   "",
   "$ ./loop.sh",
   "2026-09-05T18:31 preflight OK",
   "2026-09-05T18:31 start. remaining: 2"], 18),
 (["$ ./loop.sh",
   "2026-09-05T18:31 preflight OK",
   "2026-09-05T18:31 start. remaining: 2",
   "2026-09-05T18:31 round 1, attempt 1/5: PENDING  P1    first-real-phase",
   "  fresh agent process, new context, one phase"], 24),
 (["$ ./loop.sh",
   "2026-09-05T18:31 preflight OK",
   "2026-09-05T18:31 start. remaining: 2",
   "2026-09-05T18:31 round 1, attempt 1/5: PENDING  P1    first-real-phase",
   "  fresh agent process, new context, one phase",
   "2026-09-05T19:22 new commits: 6",
   "DONE     P1    first-real-phase              b2c3d4e",
   "2026-09-05T19:22 remaining: 1"], 26),
 (["2026-09-05T19:22 remaining: 1",
   "2026-09-05T19:22 round 2, attempt 1/5: PENDING  P2    second-phase",
   "  the process died. The ledger did not.",
   "2026-09-05T20:09 new commits: 4",
   "DONE     P2    second-phase                  c3d4e5f",
   "2026-09-05T20:09 remaining: 0"], 26),
 (["2026-09-05T20:09 remaining: 0",
   "",
   "DONE     P0    project-skeleton-and-gate     a1b2c3d",
   "DONE     P1    first-real-phase              b2c3d4e",
   "DONE     P2    second-phase                  c3d4e5f",
   "MANUAL   P9    production-cutover",
   "",
   "  FINISHED. No PENDING lines left."], 46),
]

quadros, duracoes = [], []
for linhas, ticks in ROTEIRO:
    quadros.append(desenhar(linhas))
    duracoes.append(ticks * 40)   # 40ms por tick

quadros[0].save(".media/agent-ledger-loop.gif", save_all=True, append_images=quadros[1:],
                duration=duracoes, loop=0, optimize=True)
print("gif escrito")
