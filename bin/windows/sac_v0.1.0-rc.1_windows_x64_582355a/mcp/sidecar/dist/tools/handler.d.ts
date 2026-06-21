type ToolResult = {
    content: Array<{
        type: 'text';
        text: string;
    }>;
    isError?: boolean;
};
/** MCP tool 호출을 처리한다. */
export declare function handleToolCall(name: string, args: Record<string, unknown>): Promise<ToolResult>;
export {};
