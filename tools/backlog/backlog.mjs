#!/usr/bin/env node
// CLI do backlog do projeto ar — node tools/backlog/backlog.mjs <cmd>. Sem dependências.
// Fonte: docs/backlog/itens/NNNN-slug.md (regras em docs/backlog/README.md). Quadro: docs/backlog/BACKLOG.md.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const raiz = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const dirBacklog = path.join(raiz, 'docs', 'backlog');
const dirItens = path.join(dirBacklog, 'itens');
const dirRelatorios = path.join(raiz, 'docs', 'relatorios', 'backlog');

const CAMPOS = ['id', 'titulo', 'tipo', 'urgencia', 'status', 'modulos', 'criado', 'iniciado', 'concluido', 'commits', 'relacionados', 'resumo', 'validacao'];
const LISTAS = new Set(['modulos', 'commits', 'relacionados']);
const TIPOS = ['bug', 'melhoria', 'ideia', 'feature', 'tarefa'];
const URGENCIAS = ['P0', 'P1', 'P2', 'P3'];
const STATUS = ['aberto', 'em-andamento', 'feito', 'descartado'];
const MODULOS = ['nuvem', 'automacao', 'app', 'projeto'];
const VALIDACOES = ['pendente', 'ok'];
const SECOES = ['## Contexto', '## Como reproduzir', '## Proposta', '## Notas de execução'];
// `resumo` é lido pelo dono como "o que mudou no app": sem termo técnico.
const JARGAO = [/\b[0-9a-f]{7,40}\b/i, /\bendpoint\b/i, /\bpayload\b/i, /\bcommits?\b/i, /\bPR\b/, /\bmerge\b/i, /\bstruct\b/i, /\bclass\b/i, /\bSwiftUI\b/, /\bAPI\b/, /\bKeychain\b/i, /[\w-]+\/[\w-]+\.\w+/];

const hoje = () => {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
};
const diasDesde = (data) => Math.floor((Date.now() - new Date(`${data}T00:00:00`).getTime()) / 86400e3);
const slug = (s) => s.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '').slice(0, 50);
const separarLista = (v) => (v.match(/"(?:[^"\\]|\\.)*"|[^,]+/g) ?? []).map((s) => s.trim()).filter(Boolean);

function falhar(erros) {
  for (const e of erros) console.error(`✗ ${e}`);
  process.exit(1);
}

function lerValor(v) {
  v = v.trim();
  if (v === 'null' || v === '') return null;
  if (v.startsWith('[')) return separarLista(v.slice(1, -1)).map(lerValor).filter((x) => x !== null);
  if (v.startsWith('"')) return JSON.parse(v);
  if (/^\d+$/.test(v)) return Number(v);
  return v;
}

function escreverValor(v) {
  if (v === null || v === undefined) return 'null';
  if (Array.isArray(v)) return `[${v.map((x) => (typeof x === 'number' || /^[\w.-]+$/.test(x) ? x : JSON.stringify(x))).join(', ')}]`;
  if (typeof v === 'number') return String(v);
  return /^[\w-]+$/.test(v) && !/^\d+$/.test(v) ? v : JSON.stringify(v);
}

function lerItem(arquivo) {
  const txt = fs.readFileSync(arquivo, 'utf8');
  const m = txt.match(/^---\n([\s\S]*?)\n---\n?([\s\S]*)$/);
  if (!m) falhar([`${path.basename(arquivo)}: sem frontmatter`]);
  const campos = {};
  for (const linha of m[1].split('\n')) {
    const i = linha.indexOf(':');
    if (i > 0) campos[linha.slice(0, i).trim()] = lerValor(linha.slice(i + 1));
  }
  return { arquivo, campos, corpo: m[2] };
}

function gravarItem(item) {
  const fm = CAMPOS.map((k) => `${k}: ${escreverValor(item.campos[k] ?? (LISTAS.has(k) ? [] : null))}`).join('\n');
  fs.writeFileSync(item.arquivo, `---\n${fm}\n---\n${item.corpo}`, 'utf8');
}

const itens = () =>
  fs.existsSync(dirItens)
    ? fs.readdirSync(dirItens).filter((f) => /^\d{4}-.*\.md$/.test(f)).sort().map((f) => lerItem(path.join(dirItens, f)))
    : [];

function secao(corpo, titulo) {
  const m = corpo.match(new RegExp(`^${titulo}\\n([\\s\\S]*?)(?=^## |(?![\\s\\S]))`, 'm'));
  return m ? m[1].trim() : null;
}

function validar(item) {
  const c = item.campos;
  const p = [];
  const nome = path.basename(item.arquivo);
  if (typeof c.id !== 'number' || !nome.startsWith(String(c.id).padStart(4, '0') + '-')) p.push('id não bate com o nome do arquivo');
  if (!c.titulo) p.push('sem titulo');
  if (!TIPOS.includes(c.tipo)) p.push(`tipo inválido: ${c.tipo}`);
  if (!URGENCIAS.includes(c.urgencia)) p.push(`urgencia inválida: ${c.urgencia}`);
  if (!STATUS.includes(c.status)) p.push(`status inválido: ${c.status}`);
  if (!Array.isArray(c.modulos) || !c.modulos.length || c.modulos.some((m) => !MODULOS.includes(m))) p.push(`modulos deve ser subconjunto de ${MODULOS.join(', ')}`);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(c.criado ?? '')) p.push('criado sem data AAAA-MM-DD');
  if (c.validacao !== null && c.validacao !== undefined && !VALIDACOES.includes(c.validacao)) p.push(`validacao inválida: ${c.validacao}`);
  if (c.status === 'feito') {
    if (!c.concluido) p.push('feito sem concluido');
    if (!c.commits?.length) p.push('feito sem commits');
    if (['bug', 'melhoria', 'feature'].includes(c.tipo) && !c.resumo) p.push('feito sem resumo');
  }
  if (c.status === 'descartado' && !secao(item.corpo, '## Notas de execução')) p.push('descartado sem motivo nas Notas de execução');
  if (c.resumo) for (const re of JARGAO) if (re.test(c.resumo)) p.push(`resumo com termo técnico (${re})`);
  const linhas = item.corpo.split('\n');
  const pos = SECOES.map((s) => linhas.indexOf(s));
  if (pos.some((x) => x < 0) || pos.some((x, i) => i > 0 && x < pos[i - 1])) p.push(`seções devem ser, nesta ordem: ${SECOES.join(' · ')}`);
  if (c.tipo === 'bug' && !secao(item.corpo, '## Como reproduzir')) p.push('bug sem Como reproduzir');
  return p.map((x) => `#${c.id ?? '?'} (${nome}): ${x}`);
}

function opcoes(args) {
  const o = {};
  for (let i = 0; i < args.length; i++) if (args[i].startsWith('--')) o[args[i].slice(2)] = args[++i];
  return o;
}

const linha = (c) => `#${c.id} · ${c.tipo} · ${c.urgencia} · ${c.status} · ${c.modulos.join(', ')} · ${c.titulo}`;
const ordemUrgencia = (a, b) => URGENCIAS.indexOf(a.campos.urgencia) - URGENCIAS.indexOf(b.campos.urgencia) || a.campos.id - b.campos.id;
const ativos = (lista) => lista.filter((i) => ['aberto', 'em-andamento'].includes(i.campos.status));
const aguardando = (lista) => lista.filter((i) => i.campos.status === 'feito' && i.campos.validacao === 'pendente');

function board() {
  const lista = itens();
  const quando = (c) => (c.status === 'em-andamento' ? `em andamento desde ${c.iniciado}` : `há ${diasDesde(c.criado)} dias`);
  const ouNada = (linhas) => (linhas.length ? linhas : ['- (nada)']);
  const bloco = (titulo, filtro) => [`## ${titulo}`, ...ouNada(ativos(lista).filter(filtro).sort((a, b) => a.campos.id - b.campos.id).map(({ campos: c }) => `- #${c.id} · ${c.tipo} · ${c.urgencia} · ${c.modulos.join(', ')} · ${c.titulo} · ${quando(c)}`)), ''];
  const L = [
    '# Backlog — ar',
    '',
    `> Gerado por \`backlog board\` em ${hoje()}. Não editar à mão: edite os itens em \`itens/\` e gere de novo.`,
    '',
    ...bloco('Agora', (i) => ['P0', 'P1'].includes(i.campos.urgencia)),
    ...bloco('Próximo ciclo', (i) => i.campos.urgencia === 'P2'),
    ...bloco('Quando der', (i) => i.campos.urgencia === 'P3'),
    '## Aguardando teste no aparelho',
    ...ouNada(aguardando(lista).map(({ campos: c }) => `- #${c.id} · ${c.tipo} · ${c.modulos.join(', ')} · ${c.titulo} · entregue em ${c.concluido} · ${c.commits.join(', ')}`)),
    '',
  ];
  fs.writeFileSync(path.join(dirBacklog, 'BACKLOG.md'), L.join('\n'), 'utf8');
}

function cmdNew(args) {
  const o = opcoes(args);
  const modulos = (o.modulos ?? '').split(',').map((s) => s.trim()).filter(Boolean);
  const erros = [];
  if (!o.titulo) erros.push('--titulo é obrigatório');
  if (!TIPOS.includes(o.tipo)) erros.push(`--tipo deve ser ${TIPOS.join('|')}`);
  if (!URGENCIAS.includes(o.urgencia)) erros.push(`--urgencia deve ser ${URGENCIAS.join('|')}`);
  if (!modulos.length || modulos.some((m) => !MODULOS.includes(m))) erros.push(`--modulos deve ser lista de ${MODULOS.join(',')}`);
  if (erros.length) falhar(erros);
  const id = Math.max(0, ...itens().map((i) => i.campos.id)) + 1;
  fs.mkdirSync(dirItens, { recursive: true });
  const item = {
    arquivo: path.join(dirItens, `${String(id).padStart(4, '0')}-${slug(o.titulo)}.md`),
    campos: { id, titulo: o.titulo, tipo: o.tipo, urgencia: o.urgencia, status: 'aberto', modulos, criado: hoje(), relacionados: [] },
    corpo: SECOES.map((s) => `${s}\n`).join('\n'),
  };
  gravarItem(item);
  board();
  console.log(`#${id} · ${path.relative(raiz, item.arquivo)}`);
}

function cmdSet(args) {
  const id = Number(args[0]);
  const item = itens().find((i) => i.campos.id === id);
  if (!item) falhar([`item #${args[0]} não existe`]);
  for (const par of args.slice(1)) {
    const i = par.indexOf('=');
    if (i < 0) falhar([`"${par}" não é chave=valor`]);
    const k = par.slice(0, i);
    const v = par.slice(i + 1);
    if (k === 'nota') {
      item.corpo = `${item.corpo.replace(/\s*$/, '')}\n${hoje()}: ${v}\n`;
      continue;
    }
    if (!CAMPOS.includes(k) || ['id', 'criado'].includes(k)) falhar([`campo não editável: ${k}`]);
    if (LISTAS.has(k)) {
      const novos = separarLista(v.replace(/^\+/, '')).map((x) => (k === 'relacionados' ? Number(x) : x));
      item.campos[k] = v.startsWith('+') ? [...(item.campos[k] ?? []), ...novos] : novos;
    } else {
      item.campos[k] = v === '' || v === 'null' ? null : v;
    }
    if (k === 'status' && v === 'em-andamento' && !item.campos.iniciado) item.campos.iniciado = hoje();
    if (k === 'status' && ['feito', 'descartado'].includes(v)) item.campos.concluido = hoje();
  }
  const problemas = validar(item);
  if (problemas.length) falhar(problemas);
  gravarItem(item);
  board();
  console.log(linha(item.campos));
}

function cmdList(args) {
  const o = opcoes(args);
  const em = (chave, valor) => !o[chave] || o[chave].split(',').includes(valor);
  const lista = itens().filter(({ campos: c }) => em('status', c.status) && em('urgencia', c.urgencia) && em('tipo', c.tipo) && em('validacao', c.validacao ?? '') && (!o.modulo || c.modulos.includes(o.modulo)));
  for (const i of lista.sort(ordemUrgencia)) console.log(linha(i.campos));
  if (!lista.length) console.log('(nenhum item)');
}

function cmdNext() {
  const lista = itens();
  const fila = ativos(lista).sort((a, b) => (b.campos.status === 'em-andamento') - (a.campos.status === 'em-andamento') || ordemUrgencia(a, b));
  console.log(fila.length ? fila.map((i) => linha(i.campos)).join('\n') : '(fila vazia)');
  const pend = aguardando(lista);
  if (pend.length) console.log(`\nAguardando teste no aparelho:\n${pend.map((i) => linha(i.campos)).join('\n')}`);
}

function cmdCheck() {
  const problemas = itens().flatMap(validar);
  if (problemas.length) falhar(problemas);
  console.log(`✓ ${itens().length} itens válidos`);
}

function cmdReport(args) {
  const o = opcoes(args);
  if (!/^\d{4}-\d{2}$/.test(o.periodo ?? '')) falhar(['--periodo AAAA-MM é obrigatório']);
  const tipo = o.tipo ?? 'resumo';
  if (!['resumo', 'tecnico'].includes(tipo)) falhar(['--tipo deve ser resumo|tecnico']);
  const feitos = itens().filter(({ campos: c }) => c.status === 'feito' && (c.concluido ?? '').startsWith(o.periodo));
  const mes = new Date(`${o.periodo}-15T12:00:00`).toLocaleString('pt-BR', { month: 'long', year: 'numeric' });
  const L = [];
  if (tipo === 'resumo') {
    L.push(`# O que mudou no app do ar — ${mes}`, '');
    for (const [titulo, t] of [['Correções', 'bug'], ['Melhorias', 'melhoria'], ['Novidades', 'feature']]) {
      const doTipo = feitos.filter((i) => i.campos.tipo === t);
      if (doTipo.length) L.push(`## ${titulo}`, ...doTipo.map((i) => `- ${i.campos.resumo}`), '');
    }
  } else {
    L.push(`# Backlog — relatório técnico — ${mes}`, '');
    for (const { campos: c, corpo } of feitos) {
      L.push(`## #${c.id} · ${c.titulo}`, `- ${c.tipo} · ${c.urgencia} · ${c.modulos.join(', ')} · ${c.iniciado ?? '?'} → ${c.concluido}`, `- commits: ${c.commits.join(', ')}`, `- teste no aparelho: ${c.validacao ?? 'não se aplica'}`);
      const notas = secao(corpo, '## Notas de execução');
      if (notas) L.push('', notas);
      L.push('');
    }
  }
  if (!feitos.length) L.push('(nenhum item concluído no período)', '');
  fs.mkdirSync(dirRelatorios, { recursive: true });
  const arquivo = path.join(dirRelatorios, `${o.periodo}-${tipo}.md`);
  fs.writeFileSync(arquivo, L.join('\n'), 'utf8');
  console.log(path.relative(raiz, arquivo));
}

const [cmd, ...args] = process.argv.slice(2);
const comandos = { new: cmdNew, set: cmdSet, list: cmdList, next: cmdNext, board: () => { board(); console.log('docs/backlog/BACKLOG.md'); }, check: cmdCheck, report: cmdReport };
if (!comandos[cmd]) falhar([`uso: backlog.mjs ${Object.keys(comandos).join('|')} ...  (ver docs/backlog/README.md)`]);
comandos[cmd](args);
