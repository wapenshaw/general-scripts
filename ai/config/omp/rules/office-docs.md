---
description: Reading DOCX, PPTX, XLSX, PDF and other office documents
---

# Office documents

- Prefer an adjacent Markdown extraction when one exists.
- To look at a document, use the `read` tool: it extracts text from PDF, DOCX, PPTX, XLSX and EPUB.
- To keep a Markdown copy of DOCX, PPTX, XLSX, ODT, EPUB or RTF, convert with `pandoc <file> -t gfm -o <file>.md` (add `--extract-media=<dir>` when images matter).
- Pandoc cannot read PDF. Use `pdftotext -layout <file>.pdf -` instead; a scanned PDF with no text layer needs OCR.
- Never parse raw OpenXML by hand as the first approach.
- Keep the original. Go back to it only to check visuals, comments, speaker notes or embedded content the conversion lost.
