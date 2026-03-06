import rateLimit from 'express-rate-limit';
import { Request } from 'express';

// Rate limit configuration
const WINDOW_MS = Number(process.env.RATE_LIMIT_WINDOW_MS) || 60 * 1000; // 1 minute
const MAX_REQUESTS = Number(process.env.RATE_LIMIT_MAX_REQUESTS) || 100;

/**
 * Key generator for rate limiting
 */
function keyGenerator(req: Request): string {
  // Use user ID if authenticated, otherwise use IP
  return req.user?.id || req.ip || 'unknown';
}

/**
 * Standard rate limiter
 */
export const rateLimiter = rateLimit({
  windowMs: WINDOW_MS,
  max: MAX_REQUESTS,
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator,
  handler: (req, res) => {
    res.status(429).json({
      error: 'TooManyRequests',
      message: 'Too many requests, please try again later',
      code: 'RATE_LIMIT_EXCEEDED',
      statusCode: 429,
      retryAfter: Math.ceil(WINDOW_MS / 1000),
    });
  },
});

/**
 * Strict rate limiter for auth endpoints
 */
export const authRateLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 10, // 10 requests per 15 minutes
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator,
  handler: (req, res) => {
    res.status(429).json({
      error: 'TooManyRequests',
      message: 'Too many authentication attempts, please try again later',
      code: 'AUTH_RATE_LIMIT_EXCEEDED',
      statusCode: 429,
      retryAfter: 900, // 15 minutes
    });
  },
});

/**
 * Relaxed rate limiter for read operations
 */
export const readRateLimiter = rateLimit({
  windowMs: WINDOW_MS,
  max: MAX_REQUESTS * 2, // Double the limit for reads
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator,
});

/**
 * Upload rate limiter
 */
export const uploadRateLimiter = rateLimit({
  windowMs: 60 * 60 * 1000, // 1 hour
  max: 50, // 50 uploads per hour
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator,
  handler: (req, res) => {
    res.status(429).json({
      error: 'TooManyRequests',
      message: 'Too many upload requests, please try again later',
      code: 'UPLOAD_RATE_LIMIT_EXCEEDED',
      statusCode: 429,
      retryAfter: 3600,
    });
  },
});

export default rateLimiter;
