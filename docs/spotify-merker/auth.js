// PKCE-based Spotify Authorization Code Flow

const AUTHORIZE_URL = 'https://accounts.spotify.com/authorize';
const TOKEN_URL = 'https://accounts.spotify.com/api/token';
const SCOPES = [
  'user-read-currently-playing',
  'user-read-playback-state',
  'user-modify-playback-state',
  'user-read-recently-played',
  'user-read-playback-position',
  'user-library-read',
];

// Generate a random code_verifier (64 characters)
function generateCodeVerifier() {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
  let result = '';
  for (let i = 0; i < 64; i++) {
    result += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return result;
}

// Convert base64 string to base64url (RFC 4648)
function base64ToBase64Url(b64) {
  return b64.replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '');
}

// Generate code_challenge from code_verifier
async function generateCodeChallenge(verifier) {
  const encoder = new TextEncoder();
  const data = encoder.encode(verifier);
  const hash = await crypto.subtle.digest('SHA-256', data);
  const b64 = btoa(String.fromCharCode(...new Uint8Array(hash)));
  return base64ToBase64Url(b64);
}

// Generate a random state
function generateState() {
  return Math.random().toString(36).substring(2, 15) + Math.random().toString(36).substring(2, 15);
}

// Get stored token
export function getStoredToken() {
  const json = localStorage.getItem('sm.token');
  if (!json) return null;
  try {
    return JSON.parse(json);
  } catch {
    return null;
  }
}

// Store token
export function storeToken(token) {
  localStorage.setItem('sm.token', JSON.stringify(token));
}

// Initialize login flow
export async function initiateLogin(clientId) {
  if (!clientId) {
    throw new Error('Client ID is required');
  }

  const verifier = generateCodeVerifier();
  const challenge = await generateCodeChallenge(verifier);
  const state = generateState();

  // Store verifier and state for callback
  sessionStorage.setItem('sm.codeVerifier', verifier);
  sessionStorage.setItem('sm.state', state);

  const redirectUri = location.origin + location.pathname;
  const params = new URLSearchParams({
    client_id: clientId,
    response_type: 'code',
    redirect_uri: redirectUri,
    scope: SCOPES.join(' '),
    code_challenge_method: 'S256',
    code_challenge: challenge,
    state: state,
  });

  window.location.href = `${AUTHORIZE_URL}?${params.toString()}`;
}

// Exchange authorization code for token
export async function exchangeCode(code, clientId) {
  const verifier = sessionStorage.getItem('sm.codeVerifier');
  const state = sessionStorage.getItem('sm.state');

  if (!verifier || !state) {
    throw new Error('Missing PKCE state');
  }

  const redirectUri = location.origin + location.pathname;

  const response = await fetch(TOKEN_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: new URLSearchParams({
      client_id: clientId,
      grant_type: 'authorization_code',
      code: code,
      redirect_uri: redirectUri,
      code_verifier: verifier,
    }).toString(),
  });

  if (!response.ok) {
    const error = await response.json();
    throw new Error(`Token exchange failed: ${error.error || 'unknown error'}`);
  }

  const data = await response.json();
  const token = {
    access_token: data.access_token,
    refresh_token: data.refresh_token,
    expires_at: Date.now() + (data.expires_in * 1000),
  };

  storeToken(token);
  sessionStorage.removeItem('sm.codeVerifier');
  sessionStorage.removeItem('sm.state');

  return token;
}

// Refresh token
let refreshPromise = null;

export async function refreshToken(clientId) {
  const token = getStoredToken();

  if (!token || !token.refresh_token) {
    return null;
  }

  // Prevent concurrent refreshes
  if (refreshPromise) {
    return refreshPromise;
  }

  refreshPromise = (async () => {
    try {
      const response = await fetch(TOKEN_URL, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: new URLSearchParams({
          client_id: clientId,
          grant_type: 'refresh_token',
          refresh_token: token.refresh_token,
        }).toString(),
      });

      if (!response.ok) {
        storeToken(null);
        return null;
      }

      const data = await response.json();
      const newToken = {
        access_token: data.access_token,
        refresh_token: data.refresh_token || token.refresh_token,
        expires_at: Date.now() + (data.expires_in * 1000),
      };

      storeToken(newToken);
      return newToken;
    } finally {
      refreshPromise = null;
    }
  })();

  return refreshPromise;
}

// Get access token, refreshing if necessary
export async function getAccessToken(clientId) {
  const token = getStoredToken();

  if (!token) {
    return null;
  }

  // Refresh 60 seconds before expiration
  if (Date.now() >= token.expires_at - 60000) {
    const refreshed = await refreshToken(clientId);
    if (!refreshed) {
      return null;
    }
    return refreshed.access_token;
  }

  return token.access_token;
}

// Check if user is logged in
export function isLoggedIn() {
  return getStoredToken() !== null;
}

// Logout
export function logout() {
  localStorage.removeItem('sm.token');
}

// Get redirect URI
export function getRedirectUri() {
  return location.origin + location.pathname;
}

// Get stored client ID
export function getStoredClientId() {
  return localStorage.getItem('sm.clientId');
}

// Store client ID
export function storeClientId(clientId) {
  localStorage.setItem('sm.clientId', clientId);
}
