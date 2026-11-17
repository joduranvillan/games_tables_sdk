/* @ts-self-types="./open_table_wasm.d.ts" */

export class WasmGameBridge {
    __destroy_into_raw() {
        const ptr = this.__wbg_ptr;
        this.__wbg_ptr = 0;
        WasmGameBridgeFinalization.unregister(this);
        return ptr;
    }
    free() {
        const ptr = this.__destroy_into_raw();
        wasm.__wbg_wasmgamebridge_free(ptr, 0);
    }
    /**
     * @param {string} game_type
     * @param {string} log_json
     * @returns {boolean}
     */
    apply_sync_log_json(game_type, log_json) {
        let ptr0, len0, ptr1, len1;
        try {
            ptr0 = passStringToWasm0(game_type, wasm.__wbindgen_malloc_command_export, wasm.__wbindgen_realloc_command_export);
            len0 = WASM_VECTOR_LEN;
            ptr1 = passStringToWasm0(log_json, wasm.__wbindgen_malloc_command_export, wasm.__wbindgen_realloc_command_export);
            len1 = WASM_VECTOR_LEN;
        } catch (e) {
            if (ptr1) { wasm.__wbindgen_free_command_export(ptr1, len1 * 1, 1); }
            if (ptr0) { wasm.__wbindgen_free_command_export(ptr0, len0 * 1, 1); }
            throw e;
        }
        const ret = wasm.wasmgamebridge_apply_sync_log_json(this.__wbg_ptr, ptr0, len0, ptr1, len1);
        return ret !== 0;
    }
    /**
     * @returns {number}
     */
    current_player() {
        const ret = wasm.wasmgamebridge_current_player(this.__wbg_ptr);
        return ret >>> 0;
    }
    /**
     * @returns {bigint}
     */
    current_tick() {
        const ret = wasm.wasmgamebridge_current_tick(this.__wbg_ptr);
        return BigInt.asUintN(64, ret);
    }
    /**
     * @returns {string}
     */
    export_chess_fen() {
        let deferred1_0;
        let deferred1_1;
        try {
            const ret = wasm.wasmgamebridge_export_chess_fen(this.__wbg_ptr);
            deferred1_0 = ret[0];
            deferred1_1 = ret[1];
            return getStringFromWasm0(ret[0], ret[1]);
        } finally {
            wasm.__wbindgen_free_command_export(deferred1_0, deferred1_1, 1);
        }
    }
    /**
     * @returns {string}
     */
    export_log_json() {
        let deferred1_0;
        let deferred1_1;
        try {
            const ret = wasm.wasmgamebridge_export_log_json(this.__wbg_ptr);
            deferred1_0 = ret[0];
            deferred1_1 = ret[1];
            return getStringFromWasm0(ret[0], ret[1]);
        } finally {
            wasm.__wbindgen_free_command_export(deferred1_0, deferred1_1, 1);
        }
    }
    /**
     * @param {string} join_code
     * @param {string} host_name
     * @param {string} game_type
     * @returns {string}
     */
    generate_join_qr_svg(join_code, host_name, game_type) {
        let deferred4_0;
        let deferred4_1;
        try {
            let ptr0, len0, ptr1, len1, ptr2, len2;
            try {
                ptr0 = passStringToWasm0(join_code, wasm.__wbindgen_malloc_command_export, wasm.__wbindgen_realloc_command_export);
                len0 = WASM_VECTOR_LEN;
                ptr1 = passStringToWasm0(host_name, wasm.__wbindgen_malloc_command_export, wasm.__wbindgen_realloc_command_export);
                len1 = WASM_VECTOR_LEN;
                ptr2 = passStringToWasm0(game_type, wasm.__wbindgen_malloc_command_export, wasm.__wbindgen_realloc_command_export);
                len2 = WASM_VECTOR_LEN;
            } catch (e) {
                if (ptr2) { wasm.__wbindgen_free_command_export(ptr2, len2 * 1, 1); }
                if (ptr1) { wasm.__wbindgen_free_command_export(ptr1, len1 * 1, 1); }
                if (ptr0) { wasm.__wbindgen_free_command_export(ptr0, len0 * 1, 1); }
                throw e;
            }
            const ret = wasm.wasmgamebridge_generate_join_qr_svg(this.__wbg_ptr, ptr0, len0, ptr1, len1, ptr2, len2);
            deferred4_0 = ret[0];
            deferred4_1 = ret[1];
            return getStringFromWasm0(ret[0], ret[1]);
        } finally {
            wasm.__wbindgen_free_command_export(deferred4_0, deferred4_1, 1);
        }
    }
    /**
     * @param {number} player_id
     * @returns {string}
     */
    get_legal_moves_json(player_id) {
        let deferred1_0;
        let deferred1_1;
        try {
            const ret = wasm.wasmgamebridge_get_legal_moves_json(this.__wbg_ptr, player_id);
            deferred1_0 = ret[0];
            deferred1_1 = ret[1];
            return getStringFromWasm0(ret[0], ret[1]);
        } finally {
            wasm.__wbindgen_free_command_export(deferred1_0, deferred1_1, 1);
        }
    }
    constructor() {
        const ret = wasm.wasmgamebridge_new();
        this.__wbg_ptr = ret;
        WasmGameBridgeFinalization.register(this, this.__wbg_ptr, this);
        return this;
    }
    /**
     * @param {number} player_id
     * @param {string} json_str
     * @returns {string}
     */
    send_command_json(player_id, json_str) {
        let deferred3_0;
        let deferred3_1;
        try {
            const val2 = +player_id;
            const ptr0 = passStringToWasm0(json_str, wasm.__wbindgen_malloc_command_export, wasm.__wbindgen_realloc_command_export);
            const len0 = WASM_VECTOR_LEN;
            const ret = wasm.wasmgamebridge_send_command_json(this.__wbg_ptr, val2, ptr0, len0);
            deferred3_0 = ret[0];
            deferred3_1 = ret[1];
            return getStringFromWasm0(ret[0], ret[1]);
        } finally {
            wasm.__wbindgen_free_command_export(deferred3_0, deferred3_1, 1);
        }
    }
    /**
     * @param {string} game_type
     * @param {number} human_id
     * @param {number} ai_id
     * @param {bigint} difficulty
     * @returns {boolean}
     */
    start_ai_match(game_type, human_id, ai_id, difficulty) {
        const val2 = +human_id;
        const val3 = +ai_id;
        const val4 = BigInt.asIntN(64, difficulty);
        const ptr0 = passStringToWasm0(game_type, wasm.__wbindgen_malloc_command_export, wasm.__wbindgen_realloc_command_export);
        const len0 = WASM_VECTOR_LEN;
        const ret = wasm.wasmgamebridge_start_ai_match(this.__wbg_ptr, ptr0, len0, val2, val3, val4);
        return ret !== 0;
    }
    /**
     * @param {string} game_type
     * @param {number} p1
     * @param {number} p2
     * @returns {boolean}
     */
    start_local_match(game_type, p1, p2) {
        const val2 = +p1;
        const val3 = +p2;
        const ptr0 = passStringToWasm0(game_type, wasm.__wbindgen_malloc_command_export, wasm.__wbindgen_realloc_command_export);
        const len0 = WASM_VECTOR_LEN;
        const ret = wasm.wasmgamebridge_start_local_match(this.__wbg_ptr, ptr0, len0, val2, val3);
        return ret !== 0;
    }
    /**
     * @returns {string}
     */
    step_ai_if_needed() {
        let deferred1_0;
        let deferred1_1;
        try {
            const ret = wasm.wasmgamebridge_step_ai_if_needed(this.__wbg_ptr);
            deferred1_0 = ret[0];
            deferred1_1 = ret[1];
            return getStringFromWasm0(ret[0], ret[1]);
        } finally {
            wasm.__wbindgen_free_command_export(deferred1_0, deferred1_1, 1);
        }
    }
}
if (Symbol.dispose) WasmGameBridge.prototype[Symbol.dispose] = WasmGameBridge.prototype.free;
function __wbg_get_imports() {
    const import0 = {
        __proto__: null,
        __wbg___wbindgen_throw_4c88d8bf264fd984: function(arg0, arg1) {
            throw new Error(getStringFromWasm0(arg0, arg1));
        },
        __wbindgen_init_externref_table: function() {
            const table = wasm.__wbindgen_externrefs;
            table.set(0, undefined);
            table.set(1024, undefined);
            table.set(1025, null);
            table.set(1026, true);
            table.set(1027, false);
        },
    };
    return {
        __proto__: null,
        "./open_table_wasm_bg.js": import0,
    };
}

const WasmGameBridgeFinalization = (typeof FinalizationRegistry === 'undefined')
    ? { register: () => {}, unregister: () => {} }
    : new FinalizationRegistry(ptr => wasm.__wbg_wasmgamebridge_free(ptr, 1));

function getStringFromWasm0(ptr, len) {
    ptr = ptr >>> 0;
    return decodeText(getUint8ArrayMemory0().subarray(ptr, ptr + len));
}

let cachedUint8ArrayMemory0 = null;
function getUint8ArrayMemory0() {
    if (cachedUint8ArrayMemory0 === null || cachedUint8ArrayMemory0.byteLength === 0) {
        cachedUint8ArrayMemory0 = new Uint8Array(wasm.memory.buffer);
    }
    return cachedUint8ArrayMemory0;
}

function passStringToWasm0(arg, malloc, realloc) {
    if (realloc === undefined) {
        const buf = cachedTextEncoder.encode(arg);
        const ptr = malloc(buf.length, 1) >>> 0;
        getUint8ArrayMemory0().subarray(ptr, ptr + buf.length).set(buf);
        WASM_VECTOR_LEN = buf.length;
        return ptr;
    }

    let len = arg.length;
    let ptr = malloc(len, 1) >>> 0;

    const mem = getUint8ArrayMemory0();

    let offset = 0;

    for (; offset < len; offset++) {
        const code = arg.charCodeAt(offset);
        if (code > 0x7F) break;
        mem[ptr + offset] = code;
    }
    if (offset !== len) {
        if (offset !== 0) {
            arg = arg.slice(offset);
        }
        ptr = realloc(ptr, len, len = offset + arg.length * 3, 1) >>> 0;
        const view = getUint8ArrayMemory0().subarray(ptr + offset, ptr + len);
        const ret = cachedTextEncoder.encodeInto(arg, view);

        offset += ret.written;
        ptr = realloc(ptr, len, offset, 1) >>> 0;
    }

    WASM_VECTOR_LEN = offset;
    return ptr;
}

let cachedTextDecoder = new TextDecoder('utf-8', { ignoreBOM: true });
cachedTextDecoder.decode();
const MAX_SAFARI_DECODE_BYTES = 2146435072;
let numBytesDecoded = 0;
function decodeText(bytes) {
    numBytesDecoded += bytes.length;
    if (numBytesDecoded >= MAX_SAFARI_DECODE_BYTES) {
        cachedTextDecoder = new TextDecoder('utf-8', { ignoreBOM: true });
        cachedTextDecoder.decode();
        numBytesDecoded = bytes.length;
    }
    return cachedTextDecoder.decode(bytes);
}

const cachedTextEncoder = new TextEncoder();

if (!('encodeInto' in cachedTextEncoder)) {
    cachedTextEncoder.encodeInto = function (arg, view) {
        const buf = cachedTextEncoder.encode(arg);
        view.set(buf);
        return {
            read: arg.length,
            written: buf.length
        };
    };
}

let WASM_VECTOR_LEN = 0;

let wasmModule, wasmInstance, wasm;
function __wbg_finalize_init(instance, module) {
    wasmInstance = instance;
    wasm = instance.exports;
    wasmModule = module;
    cachedUint8ArrayMemory0 = null;
    wasm.__wbindgen_start();
    return wasm;
}

async function __wbg_load(module, imports) {
    if (typeof Response === 'function' && module instanceof Response) {
        if (!module.ok) {
            throw new Error(`failed to fetch Wasm: ${module.status} ${module.statusText} fetching '${module.url}'`);
        }

        if (typeof WebAssembly.instantiateStreaming === 'function') {
            try {
                return await WebAssembly.instantiateStreaming(module, imports);
            } catch (e) {
                const validResponse = expectedResponseType(module.type);

                if (validResponse && module.headers.get('Content-Type') !== 'application/wasm') {
                    console.warn("`WebAssembly.instantiateStreaming` failed because your server does not serve Wasm with `application/wasm` MIME type. Falling back to `WebAssembly.instantiate` which is slower. Original error:\n", e);

                } else { throw e; }
            }
        }

        const bytes = await module.arrayBuffer();
        return await WebAssembly.instantiate(bytes, imports);
    } else {
        const instance = await WebAssembly.instantiate(module, imports);

        if (instance instanceof WebAssembly.Instance) {
            return { instance, module };
        } else {
            return instance;
        }
    }

    function expectedResponseType(type) {
        switch (type) {
            case 'basic': case 'cors': case 'default': return true;
        }
        return false;
    }
}

function initSync(module) {
    if (wasm !== undefined) return wasm;


    if (module !== undefined) {
        if (Object.getPrototypeOf(module) === Object.prototype) {
            ({module} = module)
        } else {
            console.warn('using deprecated parameters for `initSync()`; pass a single object instead')
        }
    }

    const imports = __wbg_get_imports();
    if (!(module instanceof WebAssembly.Module)) {
        module = new WebAssembly.Module(module);
    }
    const instance = new WebAssembly.Instance(module, imports);
    return __wbg_finalize_init(instance, module);
}

let __wbg_init_promise;
async function __wbg_init(module_or_path) {
    if (wasm !== undefined) return wasm;
    if (__wbg_init_promise === undefined) {
        __wbg_init_promise = __wbg_init_once(module_or_path);
        __wbg_init_promise.catch(() => { __wbg_init_promise = undefined; });
    }
    return __wbg_init_promise;
}

async function __wbg_init_once(module_or_path) {

    if (module_or_path !== undefined) {
        if (Object.getPrototypeOf(module_or_path) === Object.prototype) {
            ({module_or_path} = module_or_path)
        } else {
            console.warn('using deprecated parameters for the initialization function; pass a single object instead')
        }
    }

    if (module_or_path === undefined) {
        module_or_path = new URL('open_table_wasm_bg.wasm', import.meta.url);
    }
    const imports = __wbg_get_imports();

    if (typeof module_or_path === 'string' || (typeof Request === 'function' && module_or_path instanceof Request) || (typeof URL === 'function' && module_or_path instanceof URL)) {
        module_or_path = fetch(module_or_path);
    }

    const { instance, module } = await __wbg_load(await module_or_path, imports);

    return __wbg_finalize_init(instance, module);
}

export { initSync, __wbg_init as default };
