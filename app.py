from __future__ import annotations

import cgi
import html
import json
import re
from dataclasses import asdict, dataclass
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse

BASE_DIR = Path(__file__).resolve().parent
TEMPLATES_DIR = BASE_DIR / "templates"
STATIC_DIR = BASE_DIR / "static"


@dataclass
class EditorOption:
    key: str
    label: str
    css_property: str
    input_type: str
    min: int | None = None
    max: int | None = None
    step: int | None = None
    unit: str = ""
    default: str = ""


def build_options() -> list[EditorOption]:
    seed = [
        EditorOption("font-size", "Taille police", "font-size", "range", 8, 96, 1, "px", "16"),
        EditorOption("font-weight", "Graisse police", "font-weight", "range", 100, 900, 100, "", "400"),
        EditorOption("line-height", "Hauteur ligne", "line-height", "range", 1, 4, 1, "", "1"),
        EditorOption("letter-spacing", "Espacement lettres", "letter-spacing", "range", 0, 20, 1, "px", "0"),
        EditorOption("text-color", "Couleur texte", "color", "color", default="#111111"),
        EditorOption("bg-color", "Couleur fond", "background-color", "color", default="#ffffff"),
        EditorOption("width", "Largeur", "width", "range", 20, 1400, 1, "px", "300"),
        EditorOption("height", "Hauteur", "height", "range", 20, 1000, 1, "px", "200"),
        EditorOption("radius", "Arrondi", "border-radius", "range", 0, 200, 1, "px", "0"),
        EditorOption("border-width", "Bordure", "border-width", "range", 0, 40, 1, "px", "0"),
    ]
    generated: list[EditorOption] = []
    for i in range(1, 91):
        if i <= 20:
            generated.append(EditorOption(f"margin-{i}", f"Marge #{i}", "margin", "range", 0, 200, 1, "px", "0"))
        elif i <= 40:
            generated.append(EditorOption(f"padding-{i}", f"Padding #{i}", "padding", "range", 0, 200, 1, "px", "0"))
        elif i <= 55:
            generated.append(EditorOption(f"opacity-{i}", f"Opacité #{i}", "opacity", "range", 0, 100, 1, "", "100"))
        elif i <= 70:
            generated.append(EditorOption(f"rotate-{i}", f"Rotation #{i}", "--rotate", "range", -180, 180, 1, "deg", "0"))
        elif i <= 80:
            generated.append(EditorOption(f"shadow-blur-{i}", f"Ombre flou #{i}", "--shadow-blur", "range", 0, 80, 1, "px", "0"))
        else:
            generated.append(EditorOption(f"z-index-{i}", f"Z-index #{i}", "z-index", "range", -10, 9999, 1, "", "1"))
    return (seed + generated)[:100]


OPTIONS = [asdict(o) for o in build_options()]


def _escape(text: str) -> str:
    return html.escape(text)


def highlight(code: str, language: str) -> str:
    safe = _escape(code)
    if language == "html":
        safe = re.sub(r"(&lt;!--[\s\S]*?--&gt;)", r'<span class="token-comment">\1</span>', safe)
        safe = re.sub(r"(&lt;/?)([a-zA-Z0-9-]+)", r'\1<span class="token-tag">\2</span>', safe)
        safe = re.sub(r"([a-zA-Z-:]+)=(&quot;.*?&quot;|'[^']*')", r'<span class="token-attr">\1</span>=<span class="token-string">\2</span>', safe)
    elif language == "css":
        safe = re.sub(r"(/\*[\s\S]*?\*/)", r'<span class="token-comment">\1</span>', safe)
        safe = re.sub(r"([.#]?[a-zA-Z0-9_-]+)(\s*\{)", r'<span class="token-tag">\1</span>\2', safe)
        safe = re.sub(r"([a-z-]+)(\s*:)", r'<span class="token-attr">\1</span>\2', safe)
    elif language == "js":
        safe = re.sub(r"(//.*$)", r'<span class="token-comment">\1</span>', safe, flags=re.MULTILINE)
        safe = re.sub(r"\b(function|const|let|var|return|if|else|for|while|class|new|import|from|export|async|await)\b", r'<span class="token-keyword">\1</span>', safe)
        safe = re.sub(r"([\"'`].*?[\"'`])", r'<span class="token-string">\1</span>', safe)
    return "\n".join(f'<span class="line" data-line="{i+1}">{line or " "}</span>' for i, line in enumerate(safe.split("\n")))


def render_srcdoc(html_code: str, css_code: str, js_code: str) -> str:
    return f"""<!DOCTYPE html>
<html><head><style>
{css_code}
.__selected__ {{ outline: 2px dashed #f97316 !important; background: rgba(249,115,22,0.1) !important; }}
.__changed__ {{ animation: greenPulse 10s ease; }}
@keyframes greenPulse {{0%,100%{{background:rgba(34,197,94,0.1)}}50%{{background:rgba(34,197,94,0.2)}}}}
</style></head><body>
{html_code}
<script>{js_code}<\/script>
</body></html>"""


class Handler(BaseHTTPRequestHandler):
    def _send(self, status: int, body: bytes, content_type: str = "text/plain; charset=utf-8") -> None:
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _json(self, payload: dict | list, status: int = 200) -> None:
        self._send(status, json.dumps(payload).encode("utf-8"), "application/json; charset=utf-8")

    def do_GET(self) -> None:  # noqa: N802
        path = urlparse(self.path).path
        if path == "/":
            self._send(200, (TEMPLATES_DIR / "index.html").read_bytes(), "text/html; charset=utf-8")
            return
        if path.startswith("/static/"):
            rel = path.replace("/static/", "", 1)
            file = STATIC_DIR / rel
            if not file.exists() or not file.is_file():
                self._send(404, b"Not found")
                return
            if file.suffix == ".css":
                ctype = "text/css; charset=utf-8"
            elif file.suffix == ".js":
                ctype = "application/javascript; charset=utf-8"
            else:
                ctype = "text/plain; charset=utf-8"
            self._send(200, file.read_bytes(), ctype)
            return
        if path == "/index.html":
            self._send(200, b'<!doctype html><meta http-equiv="refresh" content="0; url=/" />', "text/html; charset=utf-8")
            return
        self._send(404, b"Not found")

    def _read_json(self) -> dict:
        length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(length) if length > 0 else b"{}"
        return json.loads(raw.decode("utf-8") or "{}")

    def do_POST(self) -> None:  # noqa: N802
        path = urlparse(self.path).path
        if path == "/api/options":
            self._json(OPTIONS)
            return
        if path == "/api/highlight":
            data = self._read_json()
            self._json({"html": highlight(str(data.get("code", "")), str(data.get("language", "")))})
            return
        if path == "/api/diff":
            data = self._read_json()
            old = str(data.get("old", "")).split("\n")
            new = str(data.get("new", "")).split("\n")
            max_len = max(len(old), len(new))
            changed = [i + 1 for i in range(max_len) if (old[i] if i < len(old) else "") != (new[i] if i < len(new) else "")]
            self._json({"changed": changed})
            return
        if path == "/api/render":
            data = self._read_json()
            self._json({"srcdoc": render_srcdoc(str(data.get("html", "")), str(data.get("css", "")), str(data.get("js", "")))})
            return
        if path == "/api/load":
            form = cgi.FieldStorage(fp=self.rfile, headers=self.headers, environ={"REQUEST_METHOD": "POST"})
            payload = {}
            for key in ["html", "css", "js"]:
                item = form[key] if key in form else None
                payload[key] = item.file.read().decode("utf-8") if item is not None and item.file else ""
            self._json(payload)
            return
        self._json({"error": "Not found"}, 404)


if __name__ == "__main__":
    server = ThreadingHTTPServer(("0.0.0.0", 8000), Handler)
    print("Server running on http://0.0.0.0:8000")
    server.serve_forever()
