// Lo mínimo de DER para App Attest: leer TLV y pasar firmas ECDSA de DER a r||s (lo que pide WebCrypto).

export interface Tlv {
  tag: number;
  value: Uint8Array;
  end: number;
}

export function readTlv(bytes: Uint8Array, offset = 0): Tlv {
  if (offset + 2 > bytes.length) throw new Error("der: fin inesperado");
  const tag = bytes[offset];
  let length = bytes[offset + 1];
  let start = offset + 2;
  if (length & 0x80) {
    const n = length & 0x7f;
    if (n === 0 || n > 4 || start + n > bytes.length) throw new Error("der: longitud inválida");
    length = 0;
    for (let i = 0; i < n; i++) length = (length << 8) | bytes[start + i];
    start += n;
  }
  if (start + length > bytes.length) throw new Error("der: fin inesperado");
  return { tag, value: bytes.subarray(start, start + length), end: start + length };
}

/** Firma ECDSA en DER (SEQUENCE { INTEGER r, INTEGER s }) a r||s de `size` bytes cada uno. */
export function derSignatureToRaw(der: Uint8Array, size = 32): Uint8Array<ArrayBuffer> {
  const seq = readTlv(der);
  if (seq.tag !== 0x30) throw new Error("der: no es una firma");
  const r = readTlv(seq.value, 0);
  const s = readTlv(seq.value, r.end);
  const out = new Uint8Array(size * 2);
  const put = (int: Uint8Array, at: number) => {
    let v = int;
    while (v.length > size && v[0] === 0) v = v.subarray(1);
    if (v.length > size) throw new Error("der: entero demasiado largo");
    out.set(v, at + size - v.length);
  };
  put(r.value, 0);
  put(s.value, size);
  return out;
}

/** r||s a DER (para los tests: así firma Apple). */
export function rawSignatureToDer(raw: Uint8Array): Uint8Array {
  const half = raw.length / 2;
  const int = (bytes: Uint8Array) => {
    let v = bytes;
    while (v.length > 1 && v[0] === 0 && !(v[1] & 0x80)) v = v.subarray(1);
    if (v[0] & 0x80) v = new Uint8Array([0, ...v]);
    return new Uint8Array([0x02, v.length, ...v]);
  };
  const r = int(raw.subarray(0, half));
  const s = int(raw.subarray(half));
  return new Uint8Array([0x30, r.length + s.length, ...r, ...s]);
}
