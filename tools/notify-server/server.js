const https = require('https');
const fs = require('fs');
const path = require('path');
const qrcode = require('qrcode-terminal');
const webpush = require('web-push');

const args = process.argv.slice(2);
const certPath = args[0];
const keyPath = args[1];
const port = parseInt(args[2], 10);
const lanIP = args[3];
const vapidPath = args[4];
const subscriptionsPath = args[5];
const caCertPath = args[6];

const cert = fs.readFileSync(certPath, 'utf8');
const key = fs.readFileSync(keyPath, 'utf8');
const caCert = fs.readFileSync(caCertPath, 'utf8');

// Load VAPID keys and configure web-push
const vapidKeys = JSON.parse(fs.readFileSync(vapidPath, 'utf8'));
webpush.setVapidDetails(
  'mailto:vh-notify@localhost',
  vapidKeys.publicKey,
  vapidKeys.privateKey
);

// Load/save push subscriptions
let pushSubscriptions = [];
function loadSubscriptions() {
  try {
    if (fs.existsSync(subscriptionsPath)) {
      pushSubscriptions = JSON.parse(fs.readFileSync(subscriptionsPath, 'utf8'));
    }
  } catch (e) {
    console.log('Warning: Could not load subscriptions:', e.message);
    pushSubscriptions = [];
  }
}
function saveSubscriptions() {
  fs.writeFileSync(subscriptionsPath, JSON.stringify(pushSubscriptions, null, 2));
}
loadSubscriptions();

const clients = [];

const SERVICE_WORKER = `
self.addEventListener('push', function(event) {
  var data = { title: 'VH Notify', message: '' };
  if (event.data) {
    try { data = event.data.json(); } catch (e) {}
  }
  event.waitUntil(
    self.registration.showNotification(data.title, {
      body: data.message,
      tag: 'vh-notify',
      renotify: true,
      vibrate: [200, 100, 200]
    })
  );
});

self.addEventListener('notificationclick', function(event) {
  event.notification.close();
  event.waitUntil(
    clients.matchAll({ type: 'window' }).then(function(clientList) {
      if (clientList.length > 0) return clientList[0].focus();
    })
  );
});
`;

const HTML_PAGE = `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>VH Notify</title>
<style>
  *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

  body {
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
    background: #0f1117;
    color: #e1e4e8;
    min-height: 100vh;
    padding: 1rem;
  }

  .header {
    text-align: center;
    padding: 1.5rem 0;
  }

  .header h1 {
    font-size: 1.4rem;
    font-weight: 600;
    color: #f0f0f0;
  }

  .status {
    display: inline-flex;
    align-items: center;
    gap: 0.4rem;
    margin-top: 0.5rem;
    padding: 0.3rem 0.8rem;
    border-radius: 999px;
    font-size: 0.8rem;
    font-weight: 500;
  }

  .status-dot {
    width: 8px;
    height: 8px;
    border-radius: 50%;
  }

  .status.connected { background: #1a2e1a; color: #4ade80; }
  .status.connected .status-dot { background: #4ade80; }

  .status.disconnected { background: #2e1a1a; color: #f87171; }
  .status.disconnected .status-dot { background: #f87171; }

  .status.reconnecting { background: #2e2a1a; color: #fbbf24; }
  .status.reconnecting .status-dot { background: #fbbf24; animation: pulse 1s infinite; }

  @keyframes pulse {
    0%, 100% { opacity: 1; }
    50% { opacity: 0.3; }
  }

  .enable-btn {
    display: block;
    width: 100%;
    max-width: 400px;
    margin: 1.5rem auto;
    padding: 0.9rem;
    border: none;
    border-radius: 0.6rem;
    font-size: 1rem;
    font-weight: 600;
    cursor: pointer;
    background: #3b82f6;
    color: #fff;
    transition: background 0.2s;
  }

  .enable-btn:hover { background: #2563eb; }
  .enable-btn:disabled { background: #333; color: #666; cursor: default; }

  .log-section {
    max-width: 500px;
    margin: 1.5rem auto 0;
  }

  .log-section h2 {
    font-size: 0.85rem;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    color: #888;
    margin-bottom: 0.6rem;
  }

  .diag {
    text-align: center;
    font-size: 0.7rem;
    color: #555;
    font-family: monospace;
    margin-top: 0.5rem;
  }

  .setup-box {
    max-width: 400px;
    margin: 1rem auto;
    padding: 0.8rem 1rem;
    background: #1a1d27;
    border: 1px solid #2a2d37;
    border-radius: 0.6rem;
    font-size: 0.8rem;
    line-height: 1.5;
    color: #ccc;
  }

  .setup-box strong {
    color: #f87171;
  }

  .setup-box ol {
    padding-left: 1.2rem;
    margin-top: 0.4rem;
  }

  .setup-box a {
    color: #60a5fa;
    font-weight: 600;
  }

  .log-empty {
    text-align: center;
    color: #555;
    font-size: 0.9rem;
    padding: 2rem 0;
  }

  .log-entry {
    background: #1a1d27;
    border: 1px solid #2a2d37;
    border-radius: 0.5rem;
    padding: 0.8rem;
    margin-bottom: 0.5rem;
    animation: slideIn 0.2s ease-out;
  }

  @keyframes slideIn {
    from { opacity: 0; transform: translateY(-8px); }
    to { opacity: 1; transform: translateY(0); }
  }

  .log-entry .title {
    font-weight: 600;
    font-size: 0.95rem;
    color: #f0f0f0;
  }

  .log-entry .message {
    color: #aaa;
    font-size: 0.85rem;
    margin-top: 0.2rem;
  }

  .log-entry .time {
    color: #555;
    font-size: 0.75rem;
    margin-top: 0.3rem;
  }
</style>
</head>
<body>
  <div class="header">
    <h1>VH Notify</h1>
    <div class="status disconnected" id="status">
      <span class="status-dot"></span>
      <span id="status-text">Disconnected</span>
    </div>
  </div>

  <button class="enable-btn" id="enable-btn" onclick="enableNotifications()">
    Tap to Enable Sound & Notifications
  </button>

  <div class="diag" id="diag"></div>
  <div class="setup-box" id="setup-box" style="display:none">
    <strong>Setup needed for background notifications:</strong>
    <ol>
      <li><a href="/ca.crt">Download CA certificate</a></li>
      <li>Android: Settings &rarr; Security &rarr; Encryption &amp; credentials &rarr; Install a certificate &rarr; CA certificate</li>
      <li>Close this tab completely, then re-open the URL</li>
    </ol>
  </div>

  <div class="log-section">
    <h2>Notification Log</h2>
    <div id="log">
      <div class="log-empty">No notifications yet</div>
    </div>
  </div>

<script>
  let audioCtx = null;
  let swRegistration = null;
  let pushSubscription = null;
  let audioReady = false;
  let pushStatus = 'pending';
  let notifPermission = ('Notification' in window) ? Notification.permission : 'unsupported';

  const statusEl = document.getElementById('status');
  const statusText = document.getElementById('status-text');
  const enableBtn = document.getElementById('enable-btn');
  const logEl = document.getElementById('log');
  const diagEl = document.getElementById('diag');
  const setupBox = document.getElementById('setup-box');

  function urlBase64ToUint8Array(base64String) {
    var padding = '='.repeat((4 - base64String.length % 4) % 4);
    var base64 = (base64String + padding).replace(/-/g, '+').replace(/_/g, '/');
    var rawData = atob(base64);
    var outputArray = new Uint8Array(rawData.length);
    for (var i = 0; i < rawData.length; i++) {
      outputArray[i] = rawData.charCodeAt(i);
    }
    return outputArray;
  }

  async function subscribeToPush(reg) {
    try {
      var resp = await fetch('/vapid-public-key');
      var data = await resp.json();
      var applicationServerKey = urlBase64ToUint8Array(data.key);

      var sub = await reg.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: applicationServerKey
      });

      await fetch('/subscribe', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(sub.toJSON())
      });

      pushSubscription = sub;
      pushStatus = 'active';
      updateDiag();
    } catch (err) {
      console.log('Push subscription failed:', err);
      pushStatus = 'failed';
      updateDiag();
    }
  }

  // Register service worker
  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.register('/sw.js').then(function(reg) {
      swRegistration = reg;
      updateDiag();

      // Attempt push subscription if permission already granted
      if (notifPermission === 'granted') {
        subscribeToPush(reg);
      }
    }).catch(function(err) {
      console.log('SW registration failed:', err);
      setupBox.style.display = 'block';
      updateDiag();
    });
  }

  function updateDiag() {
    var parts = [];
    parts.push('audio: ' + (audioReady ? 'ready' : 'tap button'));
    parts.push('sw: ' + (swRegistration ? 'ok' : 'no'));
    parts.push('push: ' + pushStatus);
    parts.push('notif: ' + notifPermission);
    diagEl.textContent = parts.join(' | ');
  }
  updateDiag();

  function updateBtn() {
    if (audioReady && notifPermission === 'granted' && pushStatus === 'active') {
      enableBtn.textContent = 'Sound + Push Notifications Enabled';
      enableBtn.disabled = true;
    } else if (audioReady) {
      enableBtn.textContent = 'Sound Enabled' +
        (notifPermission === 'granted' ? ' + Notifications Enabled' : '');
      enableBtn.disabled = (notifPermission === 'granted' && pushStatus !== 'active');
    }
  }

  function setStatus(state) {
    statusEl.className = 'status ' + state;
    statusText.textContent = state.charAt(0).toUpperCase() + state.slice(1);
  }

  function enableNotifications() {
    // Initialize AudioContext on user gesture (required by browsers)
    if (!audioCtx) {
      audioCtx = new (window.AudioContext || window.webkitAudioContext)();
    }
    if (audioCtx.state === 'suspended') audioCtx.resume();
    audioReady = true;

    // Play a short confirmation beep
    playNotificationSound();

    // Request notification permission
    if ('Notification' in window && notifPermission !== 'granted') {
      Notification.requestPermission().then(function(perm) {
        notifPermission = perm;
        updateBtn();
        updateDiag();

        // If granted and SW is ready, subscribe to push
        if (perm === 'granted' && swRegistration) {
          subscribeToPush(swRegistration);
        }
      });
    } else if (notifPermission === 'granted' && swRegistration && pushStatus !== 'active') {
      // Permission already granted but push not yet active — retry
      subscribeToPush(swRegistration);
    }

    updateBtn();
    updateDiag();
  }

  function playNotificationSound() {
    if (!audioCtx) {
      audioCtx = new (window.AudioContext || window.webkitAudioContext)();
    }
    if (audioCtx.state === 'suspended') audioCtx.resume();

    var now = audioCtx.currentTime;
    // Two-tone notification sound
    var freqs = [660, 880];
    for (var i = 0; i < freqs.length; i++) {
      var osc = audioCtx.createOscillator();
      var gain = audioCtx.createGain();
      osc.connect(gain);
      gain.connect(audioCtx.destination);
      osc.frequency.value = freqs[i];
      gain.gain.setValueAtTime(0.4, now + i * 0.25);
      gain.gain.exponentialRampToValueAtTime(0.01, now + i * 0.25 + 0.2);
      osc.start(now + i * 0.25);
      osc.stop(now + i * 0.25 + 0.25);
    }
  }

  function addLogEntry(title, message) {
    var empty = logEl.querySelector('.log-empty');
    if (empty) empty.remove();

    var entry = document.createElement('div');
    entry.className = 'log-entry';
    var now = new Date().toLocaleTimeString();
    entry.innerHTML =
      '<div class="title">' + escapeHtml(title) + '</div>' +
      '<div class="message">' + escapeHtml(message) + '</div>' +
      '<div class="time">' + now + '</div>';
    logEl.insertBefore(entry, logEl.firstChild);
  }

  function escapeHtml(str) {
    var div = document.createElement('div');
    div.textContent = str;
    return div.innerHTML;
  }

  function handleNotification(data) {
    var title = data.title || 'VH Notify';
    var message = data.message || '';

    addLogEntry(title, message);

    // Always play sound + vibrate (primary notification mechanism)
    playNotificationSound();
    if ('vibrate' in navigator) {
      navigator.vibrate([200, 100, 200]);
    }

    // Try system notification as bonus (works when tab is backgrounded)
    if (notifPermission === 'granted') {
      var opts = { body: message, vibrate: [200, 100, 200] };
      if (swRegistration) {
        swRegistration.showNotification(title, opts);
      } else {
        try { new Notification(title, opts); } catch (e) { /* audio is primary */ }
      }
    }
  }

  function connectSSE() {
    var evtSource = new EventSource('/events');

    evtSource.onopen = function() {
      setStatus('connected');
    };

    evtSource.addEventListener('notification', function(e) {
      try {
        var data = JSON.parse(e.data);
        handleNotification(data);
      } catch (err) {
        console.error('Failed to parse notification:', err);
      }
    });

    evtSource.onerror = function() {
      setStatus('reconnecting');
      if (evtSource.readyState === EventSource.CLOSED) {
        setStatus('disconnected');
        setTimeout(connectSSE, 3000);
      }
    };
  }

  connectSSE();
</script>
</body>
</html>`;

function parseBody(req) {
  return new Promise((resolve, reject) => {
    let body = '';
    req.on('data', chunk => { body += chunk; });
    req.on('end', () => {
      try {
        resolve(JSON.parse(body));
      } catch (e) {
        reject(e);
      }
    });
    req.on('error', reject);
  });
}

async function sendPushNotifications(title, message) {
  if (pushSubscriptions.length === 0) return 0;

  const payload = JSON.stringify({ title, message });
  const expired = [];
  let sent = 0;

  await Promise.allSettled(
    pushSubscriptions.map(async (sub, idx) => {
      try {
        await webpush.sendNotification(sub, payload);
        sent++;
      } catch (err) {
        if (err.statusCode === 410 || err.statusCode === 404) {
          expired.push(idx);
        } else {
          console.log(`Push failed for sub ${idx}:`, err.message);
        }
      }
    })
  );

  // Remove expired subscriptions
  if (expired.length > 0) {
    pushSubscriptions = pushSubscriptions.filter((_, idx) => !expired.includes(idx));
    saveSubscriptions();
    console.log(`Removed ${expired.length} expired push subscription(s)`);
  }

  return sent;
}

const server = https.createServer({ cert: cert + '\n' + caCert, key }, async (req, res) => {
  // CORS headers for local network
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  if (req.method === 'GET' && req.url === '/') {
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
    res.end(HTML_PAGE);
    return;
  }

  if (req.method === 'GET' && req.url === '/sw.js') {
    res.writeHead(200, { 'Content-Type': 'application/javascript; charset=utf-8' });
    res.end(SERVICE_WORKER);
    return;
  }

  if (req.method === 'GET' && req.url === '/vapid-public-key') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ key: vapidKeys.publicKey }));
    return;
  }

  if (req.method === 'GET' && req.url === '/ca.crt') {
    res.writeHead(200, {
      'Content-Type': 'application/x-x509-ca-cert',
      'Content-Disposition': 'attachment; filename="vh-notify-ca.crt"',
    });
    res.end(caCert);
    return;
  }

  if (req.method === 'POST' && req.url === '/subscribe') {
    try {
      const sub = await parseBody(req);

      // Deduplicate by endpoint
      const exists = pushSubscriptions.some(s => s.endpoint === sub.endpoint);
      if (!exists) {
        pushSubscriptions.push(sub);
        saveSubscriptions();
        console.log(`Push subscription added (${pushSubscriptions.length} total)`);
      }

      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ ok: true }));
    } catch (e) {
      res.writeHead(400, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: 'Invalid JSON body' }));
    }
    return;
  }

  if (req.method === 'GET' && req.url === '/events') {
    res.writeHead(200, {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      'Connection': 'keep-alive',
    });

    // Send initial comment to establish connection
    res.write(':connected\n\n');

    clients.push(res);

    req.on('close', () => {
      const idx = clients.indexOf(res);
      if (idx !== -1) clients.splice(idx, 1);
      console.log(`Client disconnected (${clients.length} connected)`);
    });

    console.log(`Client connected (${clients.length} connected)`);
    return;
  }

  if (req.method === 'POST' && req.url === '/send') {
    try {
      const data = await parseBody(req);
      const title = data.title || 'VH Notify';
      const message = data.message || '';

      const payload = `event: notification\ndata: ${JSON.stringify({ title, message })}\n\n`;

      let sseSent = 0;
      clients.forEach(client => {
        client.write(payload);
        sseSent++;
      });

      // Also send via Web Push
      const pushSent = await sendPushNotifications(title, message);

      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ ok: true, sse: sseSent, push: pushSent }));
      console.log(`Notification sent — SSE: ${sseSent}, Push: ${pushSent} — [${title}] ${message}`);
    } catch (e) {
      res.writeHead(400, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: 'Invalid JSON body' }));
    }
    return;
  }

  res.writeHead(404, { 'Content-Type': 'text/plain' });
  res.end('Not Found');
});

server.listen(port, '0.0.0.0', () => {
  const url = `https://${lanIP}:${port}`;
  console.log(`\nVH Notify Server running on ${url}`);
  console.log(`Push subscriptions loaded: ${pushSubscriptions.length}\n`);
  console.log('Scan this QR code on your phone:\n');
  qrcode.generate(url, { small: true }, (code) => {
    console.log(code);
    console.log(`\nOr open: ${url}`);
    console.log(`\nWaiting for connections... (Ctrl+C to stop)\n`);
  });
});
