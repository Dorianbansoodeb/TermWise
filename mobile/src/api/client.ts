const BASE_URL = 'http://localhost:4000';

export const apiClient = (token?: string) => {
  const request = async <T>(path: string, method: string, body?: unknown): Promise<T> => {
    const response = await fetch(`${BASE_URL}${path}`, {
      method,
      headers: {
        'Content-Type': 'application/json',
        ...(token ? { Authorization: `Bearer ${token}` } : {})
      },
      body: body ? JSON.stringify(body) : undefined
    });

    if (!response.ok) {
      const error = await response.text();
      throw new Error(error || `Request failed: ${response.status}`);
    }

    return (await response.json()) as T;
  };

  return {
    get: <T>(path: string) => request<T>(path, 'GET'),
    post: <T>(path: string, body: unknown) => request<T>(path, 'POST', body),
    put: <T>(path: string, body: unknown) => request<T>(path, 'PUT', body)
  };
};
