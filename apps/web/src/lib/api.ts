const ApiBaseUrl = import.meta.env.VITE_API_URL ?? "http://localhost:4000/api";

export async function apiRequest<T>(path: string, options: RequestInit = {}): Promise<T> {
  let response: Response;
  try {
    response = await fetch(`${ApiBaseUrl}${path}`, {
      ...options,
      headers: { "Content-Type": "application/json", ...options.headers }
    });
  } catch {
    throw new Error("Tidak dapat terhubung ke API. Pastikan server berjalan dan MySQL sudah aktif.");
  }
  if (!response.ok) {
    const error = await response.json().catch(() => ({ Message: "Terjadi kesalahan saat menghubungi server." }));
    throw new Error(error.Message ?? "Permintaan tidak berhasil.");
  }
  if (response.status === 204) return undefined as T;
  return response.json() as Promise<T>;
}