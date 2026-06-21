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
/** frontmatter와 본문을 분리하고 preview를 생성한다. */
export declare function parseMarkdownPreview(raw: string): ParsedMarkdown;
