const BASE = import.meta.env.VITE_API_URL ?? 'http://localhost:3000/api/v1';

export function getToken() {
  return localStorage.getItem('sy_admin_token');
}

export function setToken(token: string | null) {
  if (token) localStorage.setItem('sy_admin_token', token);
  else localStorage.removeItem('sy_admin_token');
}

export async function api<T = unknown>(
  path: string,
  options: { method?: string; body?: unknown } = {},
): Promise<T> {
  const res = await fetch(`${BASE}${path}`, {
    method: options.method ?? 'GET',
    headers: {
      'Content-Type': 'application/json',
      ...(getToken() ? { Authorization: `Bearer ${getToken()}` } : {}),
    },
    body: options.body ? JSON.stringify(options.body) : undefined,
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    throw new Error(
      Array.isArray(data.message) ? data.message.join(', ') : data.message ?? `Erreur ${res.status}`,
    );
  }
  return data as T;
}

export const fcfa = (n: number) => `${n.toLocaleString('fr-FR')} FCFA`;
