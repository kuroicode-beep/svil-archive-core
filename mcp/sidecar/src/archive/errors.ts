// errors.ts — SAC archive 오류 코드

export type SacArchiveErrorCode =
  | 'SAC_WORKSPACE_ROOT_NOT_FOUND'
  | 'SAC_WORKSPACE_ROOT_INVALID'
  | 'DOCUMENT_NOT_FOUND'
  | 'QUEUE_APPROVAL_REQUIRED';

export class SacArchiveError extends Error {
  readonly code: SacArchiveErrorCode;

  constructor(code: SacArchiveErrorCode, message: string) {
    super(message);
    this.code = code;
  }

  toJSON() {
    return { ok: false, error: this.code, message: this.message };
  }
}
