const editors = {
  html: document.getElementById('htmlEditor'),
  css: document.getElementById('cssEditor'),
  js: document.getElementById('jsEditor')
};
const previews = {
  html: document.getElementById('htmlPreview'),
  css: document.getElementById('cssPreview'),
  js: document.getElementById('jsPreview')
};

const frame = document.getElementById('frame');
const optionsWrap = document.getElementById('options');
let activeTab = 'html';
let selected = null;
let locked = false;
let previousCode = { html: '', css: '', js: '' };
let renderTimer;
let highlightControllers = { html: null, css: null, js: null };

function debounceRender() {
  clearTimeout(renderTimer);
  renderTimer = setTimeout(render, 180);
}

async function api(path, body, isForm = false) {
  const res = await fetch(path, {
    method: 'POST',
    body: isForm ? body : JSON.stringify(body),
    headers: isForm ? {} : { 'Content-Type': 'application/json' }
  });
  return res.json();
}

function lineOfCursor(textarea) {
  return textarea.value.substring(0, textarea.selectionStart).split('\n').length;
}

async function refreshHighlight(lang) {
  if (highlightControllers[lang]) highlightControllers[lang].abort();
  highlightControllers[lang] = new AbortController();

  const code = editors[lang].value;
  const { html } = await api('/api/highlight', { code, language: lang });
  previews[lang].innerHTML = html;

  const active = lineOfCursor(editors[lang]);
  previews[lang].querySelectorAll('.line').forEach((line) => {
    if (Number(line.dataset.line) === active) line.classList.add('active-line');
  });

  const diff = await api('/api/diff', { old: previousCode[lang], new: code });
  diff.changed.forEach((lineNo) => {
    const line = previews[lang].querySelector(`.line[data-line='${lineNo}']`);
    if (!line) return;
    line.classList.add('changed-line');
    setTimeout(() => line.classList.remove('changed-line'), 10000);
  });
  previousCode[lang] = code;
}

async function render() {
  const payload = {
    html: editors.html.value,
    css: editors.css.value,
    js: editors.js.value
  };
  const data = await api('/api/render', payload);
  frame.srcdoc = data.srcdoc;
}

function syncScroll(lang) {
  previews[lang].scrollTop = editors[lang].scrollTop;
  previews[lang].scrollLeft = editors[lang].scrollLeft;
}

function setTab(tab) {
  activeTab = tab;
  document.querySelectorAll('.tab').forEach((b) => b.classList.toggle('active', b.dataset.tab === tab));
  document.querySelectorAll('.editor').forEach((e) => e.classList.toggle('hidden', e.dataset.editor !== tab));
}

function setupTabs() {
  document.querySelectorAll('.tab').forEach((btn) => btn.addEventListener('click', () => setTab(btn.dataset.tab)));
}

function injectDefault() {
  editors.html.value = `<main class="demo"><h2>Projet</h2><p>Charge tes fichiers et édite ici.</p><button class="cta">Action</button></main>`;
  editors.css.value = `.demo{max-width:700px;margin:2rem auto;padding:1rem;border:1px solid #dbeafe;border-radius:12px}.cta{padding:8px 14px;background:#2563eb;color:#fff;border:0;border-radius:8px}`;
  editors.js.value = `document.querySelector('.cta')?.addEventListener('click',()=>console.log('OK'));`;
}

function setupEditors() {
  ['html', 'css', 'js'].forEach((lang) => {
    editors[lang].addEventListener('input', async () => {
      await refreshHighlight(lang);
      debounceRender();
    });
    editors[lang].addEventListener('click', () => refreshHighlight(lang));
    editors[lang].addEventListener('keyup', () => refreshHighlight(lang));
    editors[lang].addEventListener('scroll', () => syncScroll(lang));
  });
}

async function loadFiles() {
  const form = new FormData();
  const htmlFile = document.getElementById('htmlFile').files[0];
  const cssFile = document.getElementById('cssFile').files[0];
  const jsFile = document.getElementById('jsFile').files[0];
  if (htmlFile) form.append('html', htmlFile);
  if (cssFile) form.append('css', cssFile);
  if (jsFile) form.append('js', jsFile);

  const data = await api('/api/load', form, true);
  if (data.html) editors.html.value = data.html;
  if (data.css) editors.css.value = data.css;
  if (data.js) editors.js.value = data.js;

  await Promise.all(['html', 'css', 'js'].map(refreshHighlight));
  render();
}

function serializeBackToHtml() {
  const doc = frame.contentDocument;
  if (!doc) return;
  editors.html.value = doc.body.innerHTML;
  refreshHighlight('html');
}

function markNodeChanged(node) {
  if (!node) return;
  node.classList.remove('__changed__');
  node.classList.add('__changed__');
  setTimeout(() => node.classList.remove('__changed__'), 10000);
}

function attachVisualEditing() {
  const doc = frame.contentDocument;
  if (!doc) return;
  let drag = null;
  let resize = null;

  doc.addEventListener('click', (e) => {
    if (e.target.tagName === 'HTML' || e.target.tagName === 'BODY') return;
    doc.querySelectorAll('.__selected__').forEach((n) => n.classList.remove('__selected__'));
    selected = e.target;
    selected.classList.add('__selected__');
  });

  doc.addEventListener('mousedown', (e) => {
    if (!selected || locked) return;
    if (e.button !== 0) return;
    const rect = selected.getBoundingClientRect();
    if (e.altKey) {
      resize = { x: e.clientX, y: e.clientY, w: rect.width, h: rect.height };
      return;
    }
    drag = {
      x: e.clientX,
      y: e.clientY,
      l: parseFloat(selected.style.left || 0),
      t: parseFloat(selected.style.top || 0)
    };
    if (getComputedStyle(selected).position === 'static') selected.style.position = 'relative';
  });

  doc.addEventListener('mousemove', (e) => {
    if (drag && selected) {
      selected.style.left = `${drag.l + e.clientX - drag.x}px`;
      selected.style.top = `${drag.t + e.clientY - drag.y}px`;
      markNodeChanged(selected);
    }
    if (resize && selected) {
      selected.style.width = `${Math.max(20, resize.w + e.clientX - resize.x)}px`;
      selected.style.height = `${Math.max(20, resize.h + e.clientY - resize.y)}px`;
      markNodeChanged(selected);
    }
  });

  doc.addEventListener('mouseup', () => {
    if (drag || resize) serializeBackToHtml();
    drag = null;
    resize = null;
  });
}

function setupCanvasTools() {
  document.getElementById('addDiv').addEventListener('click', () => {
    const d = frame.contentDocument;
    const node = d.createElement('div');
    node.textContent = 'Nouveau bloc';
    node.style.padding = '10px';
    node.style.border = '1px dashed #94a3b8';
    (selected || d.body).appendChild(node);
    markNodeChanged(node);
    serializeBackToHtml();
  });

  document.getElementById('addBtn').addEventListener('click', () => {
    const d = frame.contentDocument;
    const node = d.createElement('button');
    node.textContent = 'Nouveau bouton';
    (selected || d.body).appendChild(node);
    markNodeChanged(node);
    serializeBackToHtml();
  });

  document.getElementById('dup').addEventListener('click', () => {
    if (!selected) return;
    const clone = selected.cloneNode(true);
    selected.parentElement?.appendChild(clone);
    markNodeChanged(clone);
    serializeBackToHtml();
  });

  document.getElementById('del').addEventListener('click', () => {
    if (!selected) return;
    selected.remove();
    selected = null;
    serializeBackToHtml();
  });

  document.getElementById('lock').addEventListener('click', (e) => {
    locked = !locked;
    e.target.textContent = locked ? 'Déverrouiller' : 'Verrouiller';
  });
}

async function setupOptions() {
  const options = await api('/api/options', {});
  optionsWrap.innerHTML = '';

  options.forEach((option) => {
    const wrap = document.createElement('div');
    wrap.className = 'option';
    const label = document.createElement('label');
    label.textContent = option.label;
    const input = document.createElement('input');
    input.type = option.input_type === 'color' ? 'color' : 'range';
    if (input.type === 'range') {
      input.min = option.min;
      input.max = option.max;
      input.step = option.step;
      input.value = option.default;
    } else {
      input.value = option.default || '#000000';
    }

    input.addEventListener('input', () => {
      if (!selected) return;
      if (option.css_property === '--rotate') {
        const deg = `${input.value}deg`;
        selected.style.transform = `rotate(${deg})`;
      } else if (option.css_property === '--shadow-blur') {
        selected.style.boxShadow = `0 0 ${input.value}px rgba(0,0,0,.35)`;
      } else if (option.css_property === 'opacity') {
        selected.style.opacity = String(Number(input.value) / 100);
      } else {
        selected.style.setProperty(option.css_property, `${input.value}${option.unit || ''}`);
      }
      markNodeChanged(selected);
      serializeBackToHtml();
    });

    wrap.appendChild(label);
    wrap.appendChild(input);
    optionsWrap.appendChild(wrap);
  });
}

async function boot() {
  injectDefault();
  setupTabs();
  setupEditors();
  setupCanvasTools();
  await Promise.all(['html', 'css', 'js'].map(refreshHighlight));
  await setupOptions();
  await render();

  frame.addEventListener('load', () => attachVisualEditing());
  document.getElementById('loadFiles').addEventListener('click', loadFiles);
  document.getElementById('forceRender').addEventListener('click', render);
}

boot();
