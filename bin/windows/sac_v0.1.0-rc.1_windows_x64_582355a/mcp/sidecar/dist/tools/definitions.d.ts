export declare const toolDefinitions: ({
    name: string;
    description: string;
    inputSchema: {
        type: string;
        properties: {
            project?: undefined;
            type?: undefined;
            category?: undefined;
            limit?: undefined;
            offset?: undefined;
            id?: undefined;
            include_full_body?: undefined;
            text?: undefined;
            title?: undefined;
            relative_dir?: undefined;
            token?: undefined;
            agent_id?: undefined;
            base_revision?: undefined;
            trash_item_id?: undefined;
        };
        required?: undefined;
    };
} | {
    name: string;
    description: string;
    inputSchema: {
        type: string;
        properties: {
            project: {
                type: string;
            };
            type: {
                type: string;
            };
            category: {
                type: string;
            };
            limit: {
                type: string;
                default: number;
            };
            offset: {
                type: string;
                default: number;
            };
            id?: undefined;
            include_full_body?: undefined;
            text?: undefined;
            title?: undefined;
            relative_dir?: undefined;
            token?: undefined;
            agent_id?: undefined;
            base_revision?: undefined;
            trash_item_id?: undefined;
        };
        required?: undefined;
    };
} | {
    name: string;
    description: string;
    inputSchema: {
        type: string;
        required: string[];
        properties: {
            id: {
                type: string;
                description: string;
            };
            include_full_body: {
                type: string;
                default: boolean;
            };
            project?: undefined;
            type?: undefined;
            category?: undefined;
            limit?: undefined;
            offset?: undefined;
            text?: undefined;
            title?: undefined;
            relative_dir?: undefined;
            token?: undefined;
            agent_id?: undefined;
            base_revision?: undefined;
            trash_item_id?: undefined;
        };
    };
} | {
    name: string;
    description: string;
    inputSchema: {
        type: string;
        required: string[];
        properties: {
            text: {
                type: string;
            };
            type: {
                type: string;
            };
            category: {
                type: string;
            };
            project: {
                type: string;
            };
            limit: {
                type: string;
                default: number;
            };
            offset?: undefined;
            id?: undefined;
            include_full_body?: undefined;
            title?: undefined;
            relative_dir?: undefined;
            token?: undefined;
            agent_id?: undefined;
            base_revision?: undefined;
            trash_item_id?: undefined;
        };
    };
} | {
    name: string;
    description: string;
    inputSchema: {
        type: string;
        required: string[];
        properties: {
            title: {
                type: string;
            };
            relative_dir: {
                type: string;
            };
            token: {
                type: string;
            };
            agent_id: {
                type: string;
            };
            project?: undefined;
            type?: undefined;
            category?: undefined;
            limit?: undefined;
            offset?: undefined;
            id?: undefined;
            include_full_body?: undefined;
            text?: undefined;
            base_revision?: undefined;
            trash_item_id?: undefined;
        };
    };
} | {
    name: string;
    description: string;
    inputSchema: {
        type: string;
        required: string[];
        properties: {
            id: {
                type: string;
                description?: undefined;
            };
            base_revision: {
                type: string;
            };
            token: {
                type: string;
            };
            agent_id: {
                type: string;
            };
            project?: undefined;
            type?: undefined;
            category?: undefined;
            limit?: undefined;
            offset?: undefined;
            include_full_body?: undefined;
            text?: undefined;
            title?: undefined;
            relative_dir?: undefined;
            trash_item_id?: undefined;
        };
    };
} | {
    name: string;
    description: string;
    inputSchema: {
        type: string;
        required: string[];
        properties: {
            id: {
                type: string;
                description?: undefined;
            };
            token: {
                type: string;
            };
            agent_id: {
                type: string;
            };
            project?: undefined;
            type?: undefined;
            category?: undefined;
            limit?: undefined;
            offset?: undefined;
            include_full_body?: undefined;
            text?: undefined;
            title?: undefined;
            relative_dir?: undefined;
            base_revision?: undefined;
            trash_item_id?: undefined;
        };
    };
} | {
    name: string;
    description: string;
    inputSchema: {
        type: string;
        required: string[];
        properties: {
            trash_item_id: {
                type: string;
            };
            token: {
                type: string;
            };
            agent_id: {
                type: string;
            };
            project?: undefined;
            type?: undefined;
            category?: undefined;
            limit?: undefined;
            offset?: undefined;
            id?: undefined;
            include_full_body?: undefined;
            text?: undefined;
            title?: undefined;
            relative_dir?: undefined;
            base_revision?: undefined;
        };
    };
})[];
