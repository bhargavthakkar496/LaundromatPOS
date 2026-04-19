import { createServer } from 'node:http';
import type { AddressInfo } from 'node:net';

import { createApp } from './app.js';
import { env } from './config/env.js';

const app = createApp();
const requestedPort = env.PORT;
const isDevCommand = process.env.npm_lifecycle_event === 'dev';

async function isWashPosAlreadyRunning(port: number) {
  try {
    const response = await fetch(`http://127.0.0.1:${port}/health`);
    if (!response.ok) {
      return false;
    }
    const payload = (await response.json()) as { ok?: boolean };
    return payload.ok === true;
  } catch {
    return false;
  }
}

function listenOnPort(port: number) {
  const server = createServer(app);

  return new Promise<{ server: ReturnType<typeof createServer>; port: number }>(
    (resolve, reject) => {
      server.once('error', reject);
      server.listen(port, () => {
        server.off('error', reject);
        const address = server.address() as AddressInfo | null;
        resolve({ server, port: address?.port ?? port });
      });
    },
  );
}

async function findOpenPort(startPort: number, attempts: number) {
  for (let offset = 0; offset <= attempts; offset += 1) {
    const candidatePort = startPort + offset;
    try {
      const result = await listenOnPort(candidatePort);
      return result;
    } catch (error) {
      const code = (error as NodeJS.ErrnoException).code;
      if (code !== 'EADDRINUSE') {
        throw error;
      }
    }
  }

  throw new Error(
    `No open port found between ${startPort} and ${startPort + attempts}.`,
  );
}

async function start() {
  try {
    const { port } = await listenOnPort(requestedPort);
    console.log(`WashPOS backend listening on :${port}`);
    return;
  } catch (error) {
    const code = (error as NodeJS.ErrnoException).code;
    if (code !== 'EADDRINUSE') {
      throw error;
    }
  }

  if (await isWashPosAlreadyRunning(requestedPort)) {
    console.log(
      `WashPOS backend is already running on :${requestedPort}. Reusing the existing instance.`,
    );
    process.exitCode = 0;
    return;
  }

  if (!isDevCommand) {
    throw new Error(
      `Port ${requestedPort} is already in use. Set PORT to an available port and retry.`,
    );
  }

  const { port } = await findOpenPort(requestedPort + 1, 20);
  console.warn(
    `Port ${requestedPort} is busy. WashPOS backend started on :${port} instead.`,
  );
}

start().catch((error: unknown) => {
  console.error(error);
  process.exitCode = 1;
});
