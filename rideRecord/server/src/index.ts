import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import compression from 'compression';
import morgan from 'morgan';
import { config } from 'dotenv';

// Load environment variables
config();

// Import routes
import authRoutes from './routes/auth.routes';
import ridesRoutes from './routes/rides.routes';
import syncRoutes from './routes/sync.routes';
import navigationRoutes from './routes/navigation.routes';
import statsRoutes from './routes/stats.routes';
import devicesRoutes from './routes/devices.routes';

// Import middleware
import { errorHandler } from './middleware/error.middleware';
import { rateLimiter } from './middleware/rate-limit.middleware';
import { requestLogger } from './middleware/logger.middleware';

// Import swagger
import { setupSwagger } from './config/swagger';

const app = express();
const PORT = process.env.PORT || 3000;
const HOST = process.env.HOST || '0.0.0.0';

// ===========================================
// Security Middleware
// ===========================================
app.use(helmet());
app.use(cors({
  origin: process.env.CORS_ORIGIN || '*',
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));

// ===========================================
// General Middleware
// ===========================================
app.use(compression());
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Request logging
if (process.env.NODE_ENV !== 'test') {
  app.use(morgan('combined'));
}
app.use(requestLogger);

// Rate limiting
app.use(rateLimiter);

// ===========================================
// Health Check
// ===========================================
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    version: process.env.npm_package_version || '0.1.0',
  });
});

app.get('/ready', async (req, res) => {
  try {
    // Check database connection
    const { prisma } = await import('./db');
    await prisma.$queryRaw`SELECT 1`;

    res.status(200).json({
      status: 'ready',
      checks: {
        database: 'ok',
      },
    });
  } catch (error) {
    res.status(503).json({
      status: 'not_ready',
      checks: {
        database: 'error',
        error: error instanceof Error ? error.message : 'Unknown error',
      },
    });
  }
});

// ===========================================
// API Routes
// ===========================================
const API_PREFIX = '/v1';

app.use(`${API_PREFIX}/auth`, authRoutes);
app.use(`${API_PREFIX}/rides`, ridesRoutes);
app.use(`${API_PREFIX}/sync`, syncRoutes);
app.use(`${API_PREFIX}/navigation`, navigationRoutes);
app.use(`${API_PREFIX}/stats`, statsRoutes);
app.use(`${API_PREFIX}/devices`, devicesRoutes);

// ===========================================
// API Documentation
// ===========================================
if (process.env.NODE_ENV !== 'production') {
  setupSwagger(app);
}

// ===========================================
// Error Handling
// ===========================================
app.use(errorHandler);

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    error: 'Not Found',
    message: `Route ${req.method} ${req.path} not found`,
    statusCode: 404,
  });
});

// ===========================================
// Start Server
// ===========================================
const server = app.listen(Number(PORT), HOST, () => {
  console.log(`🚀 RideRecord API Server running on http://${HOST}:${PORT}`);
  console.log(`📚 API Documentation: http://${HOST}:${PORT}/api-docs`);
  console.log(`🔍 Health Check: http://${HOST}:${PORT}/health`);
});

// Graceful shutdown
process.on('SIGTERM', async () => {
  console.log('SIGTERM received, shutting down gracefully...');

  const { prisma } = await import('./db');
  await prisma.$disconnect();

  server.close(() => {
    console.log('Server closed');
    process.exit(0);
  });
});

process.on('SIGINT', async () => {
  console.log('SIGINT received, shutting down gracefully...');

  const { prisma } = await import('./db');
  await prisma.$disconnect();

  server.close(() => {
    console.log('Server closed');
    process.exit(0);
  });
});

export default app;
