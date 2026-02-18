const htmlEditor = document.getElementById('htmlEditor');
const cssEditor = document.getElementById('cssEditor');
const jsEditor = document.getElementById('jsEditor');
const htmlHighlight = document.getElementById('htmlHighlight');
const cssHighlight = document.getElementById('cssHighlight');
const jsHighlight = document.getElementById('jsHighlight');
const preview = document.getElementById('preview');
const runBtn = document.getElementById('runBtn');
const designModeToggle = document.getElementById('designMode');
const lockNodeBtn = document.getElementById('lockNode');

const state = {
  selected: null,
  lockSelected: false,
  drag: null,
  resize: null,
};

function escapeHtml(text) {
  return text.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

function colorizeHTML(code) {
  return escapeHtml(code)
    .replace(/(&lt;!--[\s\S]*?--&gt;)/g, '<span class="token-comment">$1</span>')
    .replace(/(&lt;\/?)([a-zA-Z0-9-]+)/g, '$1<span class="token-tag">$2</span>')
    .replace(/([a-zA-Z-:]+)=(&quot;.*?&quot;|'.*?')/g, '<span class="token-attr">$1</span>=<span class="token-string">$2</span>');
}

function colorizeCSS(code) {
  return escapeHtml(code)
    .replace(/(\/\*[\s\S]*?\*\/)/g, '<span class="token-comment">$1</span>')
    .replace(/([.#]?[a-zA-Z0-9_-]+)(\s*\{)/g, '<span class="token-tag">$1</span>$2')
    .replace(/([a-z-]+)(\s*:)/g, '<span class="token-attr">$1</span>$2')
    .replace(/(:\s*)(#[0-9a-fA-F]{3,8}|\d+px|\d+%|\d+rem|\w+)/g, '$1<span class="token-string">$2</span>');
}

function colorizeJS(code) {
  return escapeHtml(code)
    .replace(/(\/\/.*$)/gm, '<span class="token-comment">$1</span>')
    .replace(/\b(function|const|let|var|return|if|else|for|while|class|new|import|from|export)\b/g, '<span class="token-keyword">$1</span>')
    .replace(/(["'`].*?["'`])/g, '<span class="token-string">$1</span>')
    .replace(/\b(\d+)\b/g, '<span class="token-number">$1</span>');
}

function flashEditor(editorKey) {
  const wrap = document.getElementById(`${editorKey}Wrap`);
  wrap.classList.remove('flash-green');
  wrap.classList.add('flash-orange');
  setTimeout(() => {
    wrap.classList.remove('flash-orange');
    wrap.classList.add('flash-green');
    setTimeout(() => wrap.classList.remove('flash-green'), 10000);
  }, 250);
}

function syncHighlights() {
  htmlHighlight.innerHTML = colorizeHTML(htmlEditor.value);
  cssHighlight.innerHTML = colorizeCSS(cssEditor.value);
  jsHighlight.innerHTML = colorizeJS(jsEditor.value);
}

function syncScroll(editor, highlight) {
  highlight.scrollTop = editor.scrollTop;
  highlight.scrollLeft = editor.scrollLeft;
}

function generateSrcdoc() {
  return `<!DOCTYPE html>
<html>
<head>
<style>
${cssEditor.value}
.__selected__ { outline: 2px dashed #f97316 !important; background: rgba(249,115,22,0.1) !important; }
.__changed__ { background: rgba(34,197,94,0.1) !important; transition: background .2s; }
.__resize-handle__ {
  position: absolute;
  width: 12px;
  height: 12px;
  right: 0;
  bottom: 0;
  background: #f97316;
  border-radius: 2px;
  cursor: nwse-resize;
  z-index: 9999;
}
</style>
</head>
<body>
${htmlEditor.value}
<script>
${jsEditor.value}
<\/script>
</body>
</html>`;
}

let renderTimeout;
function renderPreview() {
  clearTimeout(renderTimeout);
  renderTimeout = setTimeout(() => {
    preview.srcdoc = generateSrcdoc();
  }, 120);
}

function serializeIframeBody() {
  const doc = preview.contentDocument;
  if (!doc) return;
  htmlEditor.value = doc.body.innerHTML.trim();
  syncHighlights();
}

function markChanged(el) {
  if (!el) return;
  el.classList.remove('__changed__');
  el.classList.add('__changed__');
  setTimeout(() => el.classList.remove('__changed__'), 10000);
}

function selectable(el) {
  if (!el) return false;
  return !['HTML', 'BODY', 'SCRIPT', 'STYLE'].includes(el.tagName);
}

function setSelected(el) {
  const doc = preview.contentDocument;
  if (!doc) return;
  doc.querySelectorAll('.__selected__').forEach((node) => node.classList.remove('__selected__'));
  doc.querySelectorAll('.__resize-handle__').forEach((node) => node.remove());

  if (!selectable(el)) {
    state.selected = null;
    return;
  }

  state.selected = el;
  el.classList.add('__selected__');

  const style = preview.contentWindow.getComputedStyle(el);
  if (style.position === 'static') {
    el.style.position = 'relative';
  }

  const handle = doc.createElement('span');
  handle.className = '__resize-handle__';
  handle.title = 'Redimensionner';
  el.appendChild(handle);
}

function attachDesignLayer() {
  const doc = preview.contentDocument;
  if (!doc) return;

  doc.addEventListener('click', (event) => {
    if (!designModeToggle.checked) return;
    event.preventDefault();
    event.stopPropagation();
    setSelected(event.target.closest('*'));
  });

  doc.addEventListener('mousedown', (event) => {
    if (!designModeToggle.checked || !state.selected || state.lockSelected) return;
    if (event.button !== 0) return;

    const target = event.target;
    const win = preview.contentWindow;
    const rect = state.selected.getBoundingClientRect();

    if (target.classList.contains('__resize-handle__')) {
      state.resize = {
        startX: event.clientX,
        startY: event.clientY,
        startW: rect.width,
        startH: rect.height,
      };
      event.preventDefault();
      return;
    }

    if (target === state.selected || state.selected.contains(target)) {
      const pos = win.getComputedStyle(state.selected).position;
      if (pos === 'static') state.selected.style.position = 'relative';
      state.drag = {
        startX: event.clientX,
        startY: event.clientY,
        startLeft: parseFloat(state.selected.style.left || 0),
        startTop: parseFloat(state.selected.style.top || 0),
      };
      event.preventDefault();
    }
  });

  doc.addEventListener('mousemove', (event) => {
    if (state.resize && state.selected) {
      const dw = event.clientX - state.resize.startX;
      const dh = event.clientY - state.resize.startY;
      state.selected.style.width = `${Math.max(30, state.resize.startW + dw)}px`;
      state.selected.style.height = `${Math.max(20, state.resize.startH + dh)}px`;
      markChanged(state.selected);
      return;
    }

    if (state.drag && state.selected) {
      const dx = event.clientX - state.drag.startX;
      const dy = event.clientY - state.drag.startY;
      state.selected.style.left = `${state.drag.startLeft + dx}px`;
      state.selected.style.top = `${state.drag.startTop + dy}px`;
      markChanged(state.selected);
    }
  });

  doc.addEventListener('mouseup', () => {
    if (state.drag || state.resize) {
      flashEditor('html');
      serializeIframeBody();
    }
    state.drag = null;
    state.resize = null;
  });
}

function insertSnippet(targetEditor, text) {
  const start = targetEditor.selectionStart;
  const end = targetEditor.selectionEnd;
  targetEditor.setRangeText(`${text}\n`, start, end, 'end');
  targetEditor.dispatchEvent(new Event('input', { bubbles: true }));
}

function wireInputs(editor, highlight, key) {
  editor.addEventListener('input', () => {
    syncHighlights();
    flashEditor(key);
    renderPreview();
  });
  editor.addEventListener('scroll', () => syncScroll(editor, highlight));
}

function setupTabs() {
  document.querySelectorAll('.tab').forEach((tab) => {
    tab.addEventListener('click', () => {
      document.querySelectorAll('.tab').forEach((node) => node.classList.remove('active'));
      tab.classList.add('active');
      const target = tab.dataset.tab;
      document.querySelectorAll('.editor-card').forEach((card) => {
        card.classList.toggle('active', card.dataset.editor === target);
      });
    });
  });
}

function setupToolbar() {
  document.querySelectorAll('[data-insert]').forEach((btn) => {
    btn.addEventListener('click', () => insertSnippet(htmlEditor, btn.dataset.insert));
  });
  document.querySelectorAll('[data-insert-css]').forEach((btn) => {
    btn.addEventListener('click', () => insertSnippet(cssEditor, btn.dataset.insertCss));
  });
  document.querySelectorAll('[data-insert-js]').forEach((btn) => {
    btn.addEventListener('click', () => insertSnippet(jsEditor, btn.dataset.insertJs));
  });

  document.getElementById('addDiv').addEventListener('click', () => {
    const doc = preview.contentDocument;
    if (!doc) return;
    const node = doc.createElement('div');
    node.textContent = 'Nouveau bloc';
    node.style.padding = '12px';
    node.style.border = '1px dashed #94a3b8';
    (state.selected || doc.body).appendChild(node);
    markChanged(node);
    serializeIframeBody();
    flashEditor('html');
  });

  document.getElementById('addButton').addEventListener('click', () => {
    const doc = preview.contentDocument;
    if (!doc) return;
    const node = doc.createElement('button');
    node.textContent = 'Nouveau bouton';
    (state.selected || doc.body).appendChild(node);
    markChanged(node);
    serializeIframeBody();
    flashEditor('html');
  });

  document.getElementById('duplicateNode').addEventListener('click', () => {
    if (!state.selected) return;
    const clone = state.selected.cloneNode(true);
    state.selected.parentElement?.appendChild(clone);
    markChanged(clone);
    serializeIframeBody();
    flashEditor('html');
  });

  document.getElementById('deleteNode').addEventListener('click', () => {
    if (!state.selected) return;
    const parent = state.selected.parentElement;
    state.selected.remove();
    state.selected = null;
    if (parent) markChanged(parent);
    serializeIframeBody();
    flashEditor('html');
  });

  lockNodeBtn.addEventListener('click', () => {
    state.lockSelected = !state.lockSelected;
    lockNodeBtn.textContent = state.lockSelected ? 'Déverrouiller' : 'Verrouiller';
  });
}

function prettifyHtml(value) {
  return value
    .replace(/>\s*</g, '>\n<')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
}

function bootstrap() {
  htmlEditor.value = document.getElementById('defaultHtml').innerHTML.trim();
  cssEditor.value = `.layout-demo {\n  max-width: 680px;\n  margin: 2rem auto;\n  padding: 1rem;\n  border-radius: 12px;\n  border: 1px solid #dbeafe;\n}\n\n.btn {\n  background: #3b82f6;\n  color: white;\n  border: 0;\n  padding: 8px 14px;\n  border-radius: 8px;\n}`;
  jsEditor.value = `document.querySelector('.btn')?.addEventListener('click', () => {\n  console.log('Bouton cliqué');\n});`;

  syncHighlights();
  renderPreview();
}

wireInputs(htmlEditor, htmlHighlight, 'html');
wireInputs(cssEditor, cssHighlight, 'css');
wireInputs(jsEditor, jsHighlight, 'js');
setupTabs();
setupToolbar();
bootstrap();

runBtn.addEventListener('click', renderPreview);

preview.addEventListener('load', () => {
  attachDesignLayer();
});

designModeToggle.addEventListener('change', () => {
  if (!designModeToggle.checked) {
    const doc = preview.contentDocument;
    doc?.querySelectorAll('.__selected__').forEach((node) => node.classList.remove('__selected__'));
  }
});

document.getElementById('formatBtn').addEventListener('click', () => {
  htmlEditor.value = prettifyHtml(htmlEditor.value);
  syncHighlights();
  renderPreview();
  flashEditor('html');
});
