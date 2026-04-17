import { createServer } from 'node:http';

import { createApp } from './app.js';
import { env } from './config/env.js';

const app = createApp();
const server = createServer(app);

server.listen(env.PORT, () => {
  console.log(`Laundromat POS backend listening on :${env.PORT}`);
});
