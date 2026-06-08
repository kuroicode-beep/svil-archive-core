// frontmatter.ts — Markdown frontmatter 파싱 (read-only preview용)

export type ParsedMarkdown = {
  sacId?: string;
  title?: string;
  category?: string;
  project?: string;
  author?: string;
  tags?: string[];
  body: string;
  preview: string;
};

const PREVIEW_MAX = 320;

/** frontmatter와 본문을 분리하고 preview를 생성한다. */
export function parseMarkdownPreview(raw: string): ParsedMarkdown {
  const trimmed = raw.replace(/^\uFEFF/, '');
  if (!trimmed.startsWith('---')) {
    const preview = trimmed.slice(0, PREVIEW_MAX);
    return { body: trimmed, preview };
  }

  const endIndex = trimmed.indexOf('\n---', 3);
  if (endIndex < 0) {
    const preview = trimmed.slice(0, PREVIEW_MAX);
    return { body: trimmed, preview };
  }

  const yamlBlock = trimmed.slice(3, endIndex).trim();
  const body = trimmed.slice(endIndex + 4).replace(/^\n/, '');
  const values = parseSimpleYaml(yamlBlock);
  const preview = body.replace(/\s+/g, ' ').trim().slice(0, PREVIEW_MAX);

  return {
    sacId: values.sac_id,
    title: values.title,
    category: values.category ?? values.type,
    project: values.project,
    author: values.author,
    tags: values.tags ? values.tags.split(',').map((t) => t.trim()).filter(Boolean) : undefined,
    body,
    preview,
  };
}

/** 단순 YAML key:value 블록을 파싱한다. */
function parseSimpleYaml(block: string): Record<string, string> {
  const values: Record<string, string> = {};
  for (const line of block.split('\n')) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const colon = trimmed.indexOf(':');
    if (colon <= 0) continue;
    const key = trimmed.slice(0, colon).trim();
    let value = trimmed.slice(colon + 1).trim();
    if (value.startsWith('"') && value.endsWith('"') && value.length >= 2) {
      value = value.slice(1, -1);
    }
    values[key] = value;
  }
  return values;
}
