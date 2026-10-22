"""Casos do branch-guard.py. Rodar: python3 .claude/hooks/testa-hook.py

Cria repositorios temporarios (um na main com commit, um numa feature branch) e confere a decisao.
"""
import json, os, subprocess, sys, tempfile

HOOK = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'branch-guard.py')


def repo(branch):
    d = tempfile.mkdtemp()
    run = lambda *a: subprocess.run(['git', '-C', d, *a], check=True, capture_output=True)
    run('init', '-q', '-b', 'main')
    run('-c', 'user.email=t@t', '-c', 'user.name=t', 'commit', '-q', '--allow-empty', '-m', 'init')
    if branch != 'main':
        run('checkout', '-q', '-b', branch)
    return d


def decisao(cmd, cwd):
    r = subprocess.run([sys.executable, HOOK], input=json.dumps({'tool_input': {'command': cmd}}),
                       capture_output=True, text=True, cwd=cwd)
    if not r.stdout.strip():
        return 'passa'
    return json.loads(r.stdout)['hookSpecificOutput']['permissionDecision']


main, feat = repo('main'), repo('feat/x')
casos = [
    ('git commit -m x', main, 'deny'),
    ('git commit -m x', feat, 'passa'),
    (f'git -C {main} commit -m x', feat, 'deny'),
    (f'cd {feat} && git commit -m x', main, 'passa'),
    ('git add -A', feat, 'deny'),
    ('git add .', feat, 'deny'),
    ('git add CLAUDE.md', feat, 'passa'),
    ('cat > nota.txt <<EOF\ngit commit -m x\nEOF', main, 'passa'),
    ('ls -la', main, 'passa'),
]
falhas = 0
for cmd, cwd, esperado in casos:
    obtido = decisao(cmd, cwd)
    ok = obtido == esperado
    falhas += not ok
    print(('✓' if ok else '✗'), repr(cmd.split('\n')[0]), 'em', 'main' if cwd == main else 'feat', '->', obtido)
sys.exit(1 if falhas else 0)
