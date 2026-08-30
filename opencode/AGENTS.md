<!-- CODEGRAPH_START -->
## CodeGraph

In repositories indexed by CodeGraph (a `.codegraph/` directory exists at the repo root), reach for it BEFORE grep/find or reading files when you need to understand or locate code:

- **MCP tool** (when available): `codegraph_explore` answers most code questions in one call — the relevant symbols' verbatim source plus the call paths between them, including dynamic-dispatch hops grep can't follow. Name a file or symbol in the query to read its current line-numbered source. If it's listed but deferred, load it by name via tool search.
- **Shell** (always works): `codegraph explore "<symbol names or question>"` prints the same output.

If there is no `.codegraph/` directory, skip CodeGraph entirely — indexing is the user's decision.
<!-- CODEGRAPH_END -->

---

## Self Memory Improvement (AUTO, YOLO)

**ATURAN WAJIB** untuk semua agent (build, plan, subagent):

1. **SEBELUM** menjawab task apapun: `memory({mode: "search", query: "<ringkasan task>"})` — cari kesalahan/pola sukses sebelumnya. Jika ada error pattern "jangan ulang yang sama", hindari.
2. **SETELAH** task sukses (edit/write/bash/test pass): `memory({mode: "add", content: "SUCCESS: <apa yang berhasil> — pattern: <solusi> — repo: <path>"})` — jangan tunggu idle, simpan langsung.
3. **SETELAH** task gagal: `memory({mode: "add", content: "FAIL: <apa yang gagal> — cause: <sebab> — fix: <yang dicoba>"})` — agar tidak mengulang.
4. **AUTO-UPGRADE:** Jika menemukan plugin/skill yang lebih baik selama research, tawarkan `opencode plugin add <name>` dan update `opencode.jsonc`.

Semua memory adalah **project-scoped** (defaultScope project) + **user profile** cross-project. Web UI http://127.0.0.1:4747 untuk audit.

> Master orchestrator sudah YOLO (`permission: allow`) — tidak perlu konfirmasi, langsung eksekusi dan simpan.
