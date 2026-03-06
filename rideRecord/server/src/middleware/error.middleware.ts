import { Request, Response, NextFunction } from 'express';
import { Prisma } from '@prisma/client';
import { ZodError } from 'zod';

/**
 * Custom API Error class
 */
export class ApiError extends Error {
  statusCode: number;
  code: string;
  details?: Record<string, unknown>;

  constructor(
    statusCode: number,
    message: string,
    code: string = 'INTERNAL_ERROR',
    details?: Record<string, unknown>
  ) {
    super(message);
    this.statusCode = statusCode;
    this.code = code;
    this.details = details;
    this.name = 'ApiError';
  }

  static badRequest(message: string, details?: Record<string, unknown>) {
    return new ApiError(400, message, 'BAD_REQUEST', details);
  }

  static unauthorized(message: string = 'Unauthorized') {
    return new ApiError(401, message, 'UNAUTHORIZED');
  }

  static forbidden(message: string = 'Forbidden') {
    return new ApiError(403, message, 'FORBIDDEN');
  }

  static notFound(message: string = 'Not Found') {
    return new ApiError(404, message, 'NOT_FOUND');
  }

  static conflict(message: string) {
    return new ApiError(409, message, 'CONFLICT');
  }

  static validation(message: string, details?: Record<string, unknown>) {
    return new ApiError(422, message, 'VALIDATION_ERROR', details);
  }

  static internal(message: string = 'Internal Server Error') {
    return new ApiError(500, message, 'INTERNAL_ERROR');
  }
}

/**
 * Error handler middleware
 */
export function errorHandler(
  err: Error,
  req: Request,
  res: Response,
  _next: NextFunction
) {
  // Log error
  console.error(`[Error] ${req.method} ${req.path}:`, err);

  // Handle ApiError
  if (err instanceof ApiError) {
    return res.status(err.statusCode).json({
      error: err.name,
      message: err.message,
      code: err.code,
      details: err.details,
      statusCode: err.statusCode,
    });
  }

  // Handle Zod validation errors
  if (err instanceof ZodError) {
    return res.status(422).json({
      error: 'ValidationError',
      message: 'Validation failed',
      code: 'VALIDATION_ERROR',
      details: err.errors,
      statusCode: 422,
    });
  }

  // Handle Prisma errors
  if (err instanceof Prisma.PrismaClientKnownRequestError) {
    switch (err.code) {
      case 'P2002':
        return res.status(409).json({
          error: 'ConflictError',
          message: 'A record with this value already exists',
          code: 'DUPLICATE_ENTRY',
          statusCode: 409,
        });
      case 'P2025':
        return res.status(404).json({
          error: 'NotFoundError',
          message: 'Record not found',
          code: 'NOT_FOUND',
          statusCode: 404,
        });
      default:
        return res.status(400).json({
          error: 'DatabaseError',
          message: 'Database operation failed',
          code: 'DATABASE_ERROR',
          statusCode: 400,
        });
    }
  }

  if (err instanceof Prisma.PrismaClientValidationError) {
    return res.status(400).json({
      error: 'ValidationError',
      message: 'Invalid data provided',
      code: 'VALIDATION_ERROR',
      statusCode: 400,
    });
  }

  // Handle JWT errors
  if (err.name === 'JsonWebTokenError') {
    return res.status(401).json({
      error: 'UnauthorizedError',
      message: 'Invalid token',
      code: 'INVALID_TOKEN',
      statusCode: 401,
    });
  }

  if (err.name === 'TokenExpiredError') {
    return res.status(401).json({
      error: 'UnauthorizedError',
      message: 'Token expired',
      code: 'TOKEN_EXPIRED',
      statusCode: 401,
    });
  }

  // Default error
  return res.status(500).json({
    error: 'InternalServerError',
    message: process.env.NODE_ENV === 'production'
      ? 'An unexpected error occurred'
      : err.message,
    code: 'INTERNAL_ERROR',
    statusCode: 500,
  });
}

export default errorHandler;
