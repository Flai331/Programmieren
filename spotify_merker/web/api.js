// Spotify API wrapper with automatic token refresh and error handling
import { getAccessToken, refreshToken } from './auth.js';

const BASE_URL = 'https://api.spotify.com/v1';

// Make an API call to Spotify
export async function api(path, options = {}) {
  const { method = 'GET', body, clientId } = options;

  if (!clientId) {
    throw new Error('clientId is required for API calls');
  }

  let accessToken = await getAccessToken(clientId);
  if (!accessToken) {
    const error = new Error('Not logged in');
    error.status = 401;
    throw error;
  }

  let attempt = 0;
  const maxAttempts = 2; // Initial attempt + 1 retry

  while (attempt < maxAttempts) {
    const url = `${BASE_URL}${path}`;
    const headers = {
      'Authorization': `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    };

    const response = await fetch(url, {
      method,
      headers,
      body: body ? JSON.stringify(body) : undefined,
    });

    // 429 Too Many Requests
    if (response.status === 429) {
      const retryAfter = parseInt(response.headers.get('Retry-After') || '1', 10);
      await new Promise(resolve => setTimeout(resolve, retryAfter * 1000));
      attempt++;
      continue;
    }

    // 401 Unauthorized - try refresh
    if (response.status === 401 && attempt === 0) {
      const newToken = await refreshToken(clientId);
      if (newToken) {
        accessToken = newToken.access_token;
        attempt++;
        continue;
      } else {
        // Refresh failed, return error
        const error = new Error('Unauthorized');
        error.status = 401;
        error.reason = 'Not logged in';
        throw error;
      }
    }

    // 204 No Content
    if (response.status === 204) {
      return null;
    }

    // Success
    if (response.ok) {
      return await response.json();
    }

    // Other error status
    let errorData;
    try {
      errorData = await response.json();
    } catch {
      errorData = { error: { reason: 'Unknown error' } };
    }

    const error = new Error(
      errorData.error?.message || `HTTP ${response.status}`
    );
    error.status = response.status;
    error.reason = errorData.error?.reason || null;
    throw error;
  }

  throw new Error('API request failed after retries');
}

// Get currently playing track/episode
export async function getCurrentlyPlaying(clientId) {
  return api('/me/player?additional_types=track,episode', { clientId });
}

// Get recently played tracks
export async function getRecentlyPlayed(clientId, limit = 50) {
  return api(`/me/player/recently-played?limit=${limit}`, { clientId });
}

// Get available devices
export async function getDevices(clientId) {
  return api('/me/player/devices', { clientId });
}

// Start playback
export async function playTrack(clientId, deviceId, body) {
  const url = deviceId
    ? `/me/player/play?device_id=${deviceId}`
    : '/me/player/play';
  return api(url, { method: 'PUT', body, clientId });
}

// Get user's audiobooks
export async function getAudiobooks(clientId, limit = 50) {
  return api(`/me/audiobooks?limit=${limit}`, { clientId });
}

// Get audiobook chapters
export async function getAudiobookChapters(clientId, audiobookId, limit = 50, offset = 0) {
  return api(
    `/audiobooks/${audiobookId}/chapters?limit=${limit}&offset=${offset}&market=from_token`,
    { clientId }
  );
}
