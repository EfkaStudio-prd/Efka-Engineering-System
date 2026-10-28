# GEMS — hasil deep-dive stars & forks (28 Okt 2026)

Sumber: 501 repo yang kamu star + 138 repo milikmu (127 di antaranya fork), ditarik lewat
GitHub API pada 28 Okt 2026, lalu difilter per lapisan harness engineering. Angka bintang
sengaja **tidak** dicantumkan di sini karena formatnya tidak terbaca konsisten di keluaran
perintah; popularitas bukan kriteria pemilihan.

## 1. Yang benar-benar menutup celah (kandidat adopsi)

| Repo | Yang diberikannya | Menutup lapisan | Keputusan |
|---|---|---|---|
| `mksglu/context-mode` | "Sandboxes tool output (98% reduction), persists session memory" — output tool diisolasi & diringkas sebelum masuk konteks | Context discipline (R1 §7), evidence capping | **Pilot**: pola output-cap + summarization, bukan sebagai dependency |
| `mattpocock/sandcastle` | Orkestrasi coding agent **di dalam sandbox** via TypeScript (`sandcastle.run()`) | Eksekusi terisolasi (skor 2/10) | **Referensi desain** untuk P1 executor |
| `alibaba/open-code-review` | Review hybrid: pipeline deterministik + agent, komentar per baris, **coverage manifest immutable** | Kontrak review + verifier | **Pilot**: ambil pola manifest/coverage, bukan seluruh service |
| `SWE-agent/mini-SWE-agent` | `DockerEnvironment(executable="podman")` — pola executor Podman nyata, MIT | Eksekusi terisolasi | **Pilot**: baseline executor pada spike P1 |
| `morluto/flameox` (kamu sudah fork) | "Runtime evidence that helps agents trace, profile…" | Evidence/receipt per aksi | **Referensi**: format bukti runtime, bukan tool wajib |
| `slima4/claude-tui` | Statusline, live monitor, **session analytics + hooks** | Observabilitas agen | **Pilot ringan**: ambil ide hook → log sesi |
| `tirth8205/code-review-graph` | Graph intelijen kode lokal-first untuk MCP/CLI | Knowledge base kode | **Evaluasi** saat repo besar (gantinya `codegraph` yang sudah kamu pakai) |
| `Egonex-AI/Understand-Anything` | Knowledge graph interaktif dari kode | Knowledge base | **Referensi** tampilan/struktur |
| `griffinmartin/opencode-claude-auth` | Pakai kredensial Claude Code yang ada di OpenCode | Lane OpenCode | **Pilot** bila mau hindari login ganda |
| `EfkaStudio-prd/benchmark-harnesses` (fork) | Harness benchmark berbasis Strands | Eval | **Pilot** jangka menengah |
| `zhaoxuya520/reverse-skill` | Router pack skill RE/security | Lane reverse engineering | **Referensi** katalog |
| `ai-boost/awesome-harness-engineering` (kamu fork) | Katalog pola: permissions, evals, memory, observability | Peta kerja | **Referensi** (sudah dipakai di R1) |

## 2. Yang sengaja ditolak

| Repo | Alasan |
|---|---|
| `openclaw/openclaw` | Runtime asisten besar; kita tidak membangun gateway baru |
| `bytedance/deer-flow` | Arsitektur panjang-horizon menarik, tapi surface-nya terlalu besar untuk baseline 16 GB |
| `n8n-io/n8n`, `langgenius/dify`, `langflow-ai/langflow` | Platform workflow/RAG, bukan lapisan gerbang/harness lokal |
| `ComposioHQ/composio`, `Portkey-AI/gateway`, `BerriAI/litellm` | Gateway/router; 9Router sudah mengisi peran itu di host ini |
| `Tencent/AI-Infra-Guard` | Red teaming platform; berguna nanti, bukan sekarang |
| `lxf746/any-auto-register`, `angelafeliciaa/kip` | Melanggar ToS platform / menyentuh kredensial secara agresif |
| `affaan-m/ECC`, `MemPalace/mempalace`, `rohitg00/agentmemory` | Klaim benchmark tidak terverifikasi; memori otomatis ditunda (R0 §11) |

## 3. Pola yang diambil dari fork-mu sendiri

- `EfkaStudio-prd/rea` — REA (reverse engineering agent) yang sekarang dipakai sebagai skill
  `reverse-engineer-anything`.
- `EfkaStudio-prd/visual-explainer` — generator HTML/slide untuk artefak visual (kandidat skill
  presentasi, belum dipasang).
- `EfkaStudio-prd/codex`, `EfkaStudio-prd/CLI-Anything`, `EfkaStudio-prd/awesome-harness-engineering` —
  referensi worker/wrapping/katalog, sudah tercatat di dokumen riset.

## 4. Kesimpulan untuk sistem ini

Tiga hal yang paling cepat menaikkan skor (dari 44%) dan **tidak** memerlukan dependency baru:

1. **Output sandboxing + receipt** (pola `context-mode` + `flameox`) → lapisan evidence.
2. **Executor Podman dengan pola `mini-SWE-agent`** (image dipin, network none, limit) → lapisan isolasi.
3. **Coverage manifest review** (pola `open-code-review`) → lapisan verifikasi.

Sisanya referensi; memasang semuanya akan menambah permukaan serangan tanpa menambah bukti.
