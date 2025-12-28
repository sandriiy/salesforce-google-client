const BASE64_KEY = 'elS+WKi0ncpA+IOFAY7224YNLSTsO6syYQ5zKkGffJ8=';

function b64ToBytes(b64) {
    const bin = atob(b64);
    const bytes = new Uint8Array(bin.length);
    for (let i = 0; i < bin.length; i++) {
        bytes[i] = bin.charCodeAt(i);
    }
    return bytes;
}

async function getKey() {
    const keyBytes = b64ToBytes(BASE64_KEY);
    return crypto.subtle.importKey(
        'raw',
        keyBytes,
        { name: 'AES-GCM' },
        false,
        ['encrypt', 'decrypt']
    );
}


export async function encryptObject(obj) {
    const key = await getKey();
    const iv = crypto.getRandomValues(new Uint8Array(12));
    const encoder = new TextEncoder();
    const data = encoder.encode(JSON.stringify(obj));
    const cipher = await crypto.subtle.encrypt(
        { name: 'AES-GCM', iv },
        key,
        data
    );

    const ivB64 = btoa(String.fromCharCode(...iv));
    const cipherB64 = btoa(String.fromCharCode(...new Uint8Array(cipher)));
    return `${ivB64}:${cipherB64}`;
}

export async function decryptObject(token) {
    const [ivB64, cipherB64] = token.split(':');
    const iv = b64ToBytes(ivB64);
    const cipher = b64ToBytes(cipherB64);
    const key = await getKey();
    const plain = await crypto.subtle.decrypt(
        { name: 'AES-GCM', iv },
        key,
        cipher
    );
    const decoder = new TextDecoder();
    return JSON.parse(decoder.decode(plain));
}
