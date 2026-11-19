/* tslint:disable */
/* eslint-disable */

export class WasmGameBridge {
    free(): void;
    [Symbol.dispose](): void;
    apply_sync_log_json(game_type: string, log_json: string): boolean;
    current_player(): number;
    current_tick(): bigint;
    export_chess_fen(): string;
    export_log_json(): string;
    force_timeout_win(winner_id: number): void;
    generate_join_qr_svg(join_code: string, host_name: string, game_type: string): string;
    get_current_game_type(): string;
    get_current_replay_step(): number;
    get_legal_moves_json(player_id: number): string;
    get_replay_step_count(): number;
    get_state_json(): string;
    is_replay_at_live_head(): boolean;
    constructor();
    seek_replay_step(step_index: number): boolean;
    send_command_json(player_id: number, json_str: string): string;
    start_ai_match(game_type: string, human_id: number, ai_id: number, difficulty: bigint): boolean;
    start_local_match(game_type: string, p1: number, p2: number): boolean;
    step_ai_if_needed(): string;
}

export type InitInput = RequestInfo | URL | Response | BufferSource | WebAssembly.Module;

export interface InitOutput {
    readonly memory: WebAssembly.Memory;
    readonly __wbg_wasmgamebridge_free: (a: number, b: number) => void;
    readonly wasmgamebridge_apply_sync_log_json: (a: number, b: number, c: number, d: number, e: number) => number;
    readonly wasmgamebridge_current_player: (a: number) => number;
    readonly wasmgamebridge_current_tick: (a: number) => bigint;
    readonly wasmgamebridge_export_chess_fen: (a: number) => [number, number];
    readonly wasmgamebridge_export_log_json: (a: number) => [number, number];
    readonly wasmgamebridge_force_timeout_win: (a: number, b: number) => void;
    readonly wasmgamebridge_generate_join_qr_svg: (a: number, b: number, c: number, d: number, e: number, f: number, g: number) => [number, number];
    readonly wasmgamebridge_get_current_game_type: (a: number) => [number, number];
    readonly wasmgamebridge_get_current_replay_step: (a: number) => number;
    readonly wasmgamebridge_get_legal_moves_json: (a: number, b: number) => [number, number];
    readonly wasmgamebridge_get_replay_step_count: (a: number) => number;
    readonly wasmgamebridge_get_state_json: (a: number) => [number, number];
    readonly wasmgamebridge_is_replay_at_live_head: (a: number) => number;
    readonly wasmgamebridge_new: () => number;
    readonly wasmgamebridge_seek_replay_step: (a: number, b: number) => number;
    readonly wasmgamebridge_send_command_json: (a: number, b: number, c: number, d: number) => [number, number];
    readonly wasmgamebridge_start_ai_match: (a: number, b: number, c: number, d: number, e: number, f: bigint) => number;
    readonly wasmgamebridge_start_local_match: (a: number, b: number, c: number, d: number, e: number) => number;
    readonly wasmgamebridge_step_ai_if_needed: (a: number) => [number, number];
    readonly __wbindgen_externrefs: WebAssembly.Table;
    readonly __wbindgen_malloc_command_export: (a: number, b: number) => number;
    readonly __wbindgen_realloc_command_export: (a: number, b: number, c: number, d: number) => number;
    readonly __wbindgen_free_command_export: (a: number, b: number, c: number) => void;
    readonly __wbindgen_start: () => void;
}

export type SyncInitInput = BufferSource | WebAssembly.Module;

/**
 * Instantiates the given `module`, which can either be bytes or
 * a precompiled `WebAssembly.Module`.
 *
 * @param {{ module: SyncInitInput }} module - Passing `SyncInitInput` directly is deprecated.
 *
 * @returns {InitOutput}
 */
export function initSync(module: { module: SyncInitInput } | SyncInitInput): InitOutput;

/**
 * If `module_or_path` is {RequestInfo} or {URL}, makes a request and
 * for everything else, calls `WebAssembly.instantiate` directly.
 *
 * @param {{ module_or_path: InitInput | Promise<InitInput> }} module_or_path - Passing `InitInput` directly is deprecated.
 *
 * @returns {Promise<InitOutput>}
 */
export default function __wbg_init (module_or_path?: { module_or_path: InitInput | Promise<InitInput> } | InitInput | Promise<InitInput>): Promise<InitOutput>;
