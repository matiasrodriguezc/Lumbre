// Decodificador CBOR mínimo (RFC 8949) para los objetos de App Attest: enteros, bytes, texto, arrays, mapas,
// etiquetas (se ignoran) y simples (false, true, null). Sin longitudes indefinidas: Apple no las usa.

export type CborValue = number | bigint | string | boolean | null | Uint8Array | CborValue[] | Map<CborValue, CborValue>;

export class CborError extends Error {}

export function decodeCbor(bytes: Uint8Array): CborValue {
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  let offset = 0;

  function need(n: number) {
    if (offset + n > bytes.length) throw new CborError("cbor: fin inesperado");
  }

  function length(info: number): number {
    if (info < 24) return info;
    if (info === 24) { need(1); return bytes[offset++]; }
    if (info === 25) { need(2); const v = view.getUint16(offset); offset += 2; return v; }
    if (info === 26) { need(4); const v = view.getUint32(offset); offset += 4; return v; }
    if (info === 27) {
      need(8);
      const v = view.getBigUint64(offset);
      offset += 8;
      if (v > BigInt(Number.MAX_SAFE_INTEGER)) throw new CborError("cbor: número demasiado grande");
      return Number(v);
    }
    throw new CborError("cbor: longitud indefinida o inválida");
  }

  function item(depth: number): CborValue {
    if (depth > 32) throw new CborError("cbor: demasiado anidado");
    need(1);
    const initial = bytes[offset++];
    const major = initial >> 5;
    const info = initial & 0x1f;
    switch (major) {
      case 0: return length(info);
      case 1: return -1 - length(info);
      case 2: { const n = length(info); need(n); const v = bytes.slice(offset, offset + n); offset += n; return v; }
      case 3: { const n = length(info); need(n); const v = new TextDecoder().decode(bytes.subarray(offset, offset + n)); offset += n; return v; }
      case 4: { const n = length(info); const out: CborValue[] = []; for (let i = 0; i < n; i++) out.push(item(depth + 1)); return out; }
      case 5: {
        const n = length(info);
        const out = new Map<CborValue, CborValue>();
        for (let i = 0; i < n; i++) { const k = item(depth + 1); out.set(k, item(depth + 1)); }
        return out;
      }
      case 6: length(info); return item(depth + 1);
      default:
        if (info === 20) return false;
        if (info === 21) return true;
        if (info === 22 || info === 23) return null;
        throw new CborError("cbor: tipo simple no soportado");
    }
  }

  const value = item(0);
  return value;
}

/** Lee una clave de texto de un mapa CBOR. */
export function field(map: CborValue | undefined, key: string): CborValue | undefined {
  return map instanceof Map ? map.get(key) : undefined;
}
