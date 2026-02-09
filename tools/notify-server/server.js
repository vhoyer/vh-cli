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

const publicDir = path.join(__dirname, 'public');
const SERVICE_WORKER = fs.readFileSync(path.join(publicDir, 'sw.js'), 'utf8');
const HTML_PAGE = fs.readFileSync(path.join(publicDir, 'index.html'), 'utf8');

const clients = [];

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
