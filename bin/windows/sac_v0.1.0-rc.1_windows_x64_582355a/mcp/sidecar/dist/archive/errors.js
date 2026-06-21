// errors.ts — SAC archive 오류 코드
export class SacArchiveError extends Error {
    code;
    constructor(code, message) {
        super(message);
        this.code = code;
    }
    toJSON() {
        return { ok: false, error: this.code, message: this.message };
    }
}
