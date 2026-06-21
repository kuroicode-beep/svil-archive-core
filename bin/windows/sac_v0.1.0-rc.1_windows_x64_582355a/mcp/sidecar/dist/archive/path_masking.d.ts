/** 사용자 홈·민감 경로를 masking한다. */
export declare function maskArtifactPath(inputPath: string): string;
/** 설정 값에 secret/token 패턴이 있으면 masking한다. */
export declare function maskSensitiveValue(key: string, value: string): string;
/** 응답 JSON에 절대경로가 포함되지 않았는지 검사한다. */
export declare function containsAbsolutePathLeak(text: string): boolean;
