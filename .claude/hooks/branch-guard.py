"""PreToolUse guard de git do projeto ar (uma sessao, Claude commita em feature branch).

Regras:
  * `git commit` em main/master  -> DENY (crie feature branch).
  * `git add -A` / `--all` / `git add .` -> DENY (adicione arquivo por arquivo; evita
    commitar segredo ou arquivo gerado por engano).

Notas de implementacao (do guia SuperBrain):
  * bloqueia via hookSpecificOutput.permissionDecision. `sys.exit(1)` NAO bloqueia nada.
  * descobre o repositorio a partir de `cd <path> &&` ou `git -C <path>` no proprio comando.
  * ignora corpo de heredoc antes de casar a regex (texto gravado com "git commit" dentro
    nao e um commit).
"""
import sys, json, re, subprocess

try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)

command = (data.get('tool_input', {}) or {}).get('command', '') or ''

_HEREDOC_INI = re.compile(r'<<-?\s*(["\']?)([A-Za-z_][A-Za-z0-9_]*)\1')


def sem_heredoc(cmd):
    """Devolve o comando sem os corpos de heredoc (a linha que abre e preservada)."""
    linhas = cmd.split('\n')
    saida = []
    i = 0
    while i < len(linhas):
        linha = linhas[i]
        saida.append(linha)
        delims = [m.group(2) for m in _HEREDOC_INI.finditer(linha)]
        i += 1
        for delim in delims:
            while i < len(linhas) and linhas[i].strip() != delim:
                i += 1
            if i < len(linhas):
                i += 1
    return '\n'.join(saida)


executavel = sem_heredoc(command)

if not re.search(r'\bgit\b', executavel):
    sys.exit(0)


def decidir(decisao, motivo):
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": decisao,
            "permissionDecisionReason": motivo,
        }
    }))
    sys.exit(0)


def _arg(m):
    return m.group(2) or m.group(3) or m.group(4)


def repo_dir(cmd):
    """Diretorio do repo alvo, inferido do comando; None = usar o CWD do hook."""
    m = re.search(r'git\s+-C\s+("([^"]+)"|\'([^\']+)\'|(\S+))', cmd)
    if m:
        return _arg(m)
    m = re.search(r'(?:^|;|&&)\s*cd\s+("([^"]+)"|\'([^\']+)\'|(\S+))\s*(?:&&|;)', cmd)
    if m:
        return _arg(m)
    return None


def branch_atual():
    argv = ['git']
    d = repo_dir(executavel)
    if d:
        argv += ['-C', d]
    argv += ['branch', '--show-current']
    try:
        return subprocess.check_output(argv, text=True, stderr=subprocess.DEVNULL).strip()
    except Exception:
        return None


# Um "segmento" e um comando git isolado (sem atravessar pipe/`;`/`&&`).
SEG = r'\bgit\b[^|;&\n]*?'

# --- git add -A / --all / . ----------------------------------------------------
m = re.search(SEG + r'\badd\b([^|;&\n]*)', executavel)
if m:
    args = m.group(1)
    if re.search(r'(^|\s)(-A|--all|-[a-zA-Z]*A[a-zA-Z]*)(\s|$)', args) or re.search(r'(^|\s)\.{1,2}/?(\s|$)', args):
        decidir("deny",
                "BLOQUEADO: `git add -A` / `git add .` pode levar segredo ou arquivo gerado. "
                "Adicione arquivo por arquivo: `git add <caminho>`.")

# --- git commit em main/master --------------------------------------------------
if re.search(SEG + r'\bcommit\b', executavel):
    branch = branch_atual()
    if branch is None:
        decidir("ask", "ATENCAO (commit): nao consegui verificar a branch atual. Confirme que nao e a main.")
    if branch in ('main', 'master'):
        decidir("deny",
                "BLOQUEADO: commit direto em [%s] nao e permitido. Crie uma feature branch "
                "primeiro (feat/ | fix/ | refactor/ | chore/)." % branch)

sys.exit(0)
