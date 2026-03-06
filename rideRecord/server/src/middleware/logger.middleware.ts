import { Request, Response, NextFunction } from 'express';

/**
 * Request logger middleware
 */
export function requestLogger(req: Request, res: Response, next: NextFunction) {
  const start = Date.now();

  // Log request
  console.log(`[Request] ${req.method} ${req.path}`, {
    ip: req.ip,
    userAgent: req.get('user-agent'),
    userId: req.user?.id,
  });

  // Log response on finish
  res.on('finish', () => {
    const duration = Date.now() - start;
    const level = res.statusCode >= 400 ? 'ERROR' : 'INFO';

    console.log(`[Response] ${req.method} ${req.path}`, {
      statusCode: res.statusCode,
      duration: `${duration}ms`,
      level,
    });
  });

  next();
}

/**
 * Log error details
 */
export function logError(error: Error, req: Request) {
  console.error('[Error]', {
    message: error.message,
    stack: error.stack,
    method: req.method,
    path: req.path,
    body: req.body,
    query: req.query,
    params: req.params,
    user: req.user?.id,
    ip: req.ip,
  });
}

export default requestLogger;
