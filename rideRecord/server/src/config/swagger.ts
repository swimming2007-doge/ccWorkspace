import { Express } from 'express';
import swaggerUi from 'swagger-ui-express';
import YAML from 'yamljs';

/**
 * Swagger API Documentation Setup
 */
export function setupSwagger(app: Express): void {
  const swaggerDocument = {
    openapi: '3.0.0',
    info: {
      title: 'RideRecord API',
      version: '0.1.0',
      description: '智能骑行记录应用 API 文档',
      contact: {
        name: 'RideRecord Team',
        email: 'support@riderecord.com',
      },
    },
    servers: [
      {
        url: 'http://localhost:3000/v1',
        description: 'Development server',
      },
      {
        url: 'https://api.riderecord.com/v1',
        description: 'Production server',
      },
    ],
    components: {
      securitySchemes: {
        bearerAuth: {
          type: 'http',
          scheme: 'bearer',
          bearerFormat: 'JWT',
        },
      },
      schemas: {
        User: {
          type: 'object',
          properties: {
            id: { type: 'string' },
            nickname: { type: 'string' },
            avatar: { type: 'string' },
            email: { type: 'string' },
            height: { type: 'number' },
            weight: { type: 'number' },
            maxHeartRate: { type: 'integer' },
          },
        },
        Ride: {
          type: 'object',
          properties: {
            id: { type: 'string' },
            title: { type: 'string' },
            startTime: { type: 'string', format: 'date-time' },
            endTime: { type: 'string', format: 'date-time' },
            duration: { type: 'integer' },
            distance: { type: 'number' },
            avgSpeed: { type: 'number' },
            maxSpeed: { type: 'number' },
            calories: { type: 'integer' },
            status: { type: 'string', enum: ['recording', 'paused', 'completed', 'discarded'] },
          },
        },
        Error: {
          type: 'object',
          properties: {
            error: { type: 'string' },
            message: { type: 'string' },
            code: { type: 'string' },
            statusCode: { type: 'integer' },
          },
        },
      },
    },
    security: [
      {
        bearerAuth: [],
      },
    ],
    paths: {
      '/auth/login': {
        post: {
          tags: ['Auth'],
          summary: 'Login with Huawei OAuth',
          security: [],
          responses: {
            '200': { description: 'Login successful' },
            '401': { description: 'Unauthorized' },
          },
        },
      },
      '/auth/me': {
        get: {
          tags: ['Auth'],
          summary: 'Get current user info',
          responses: {
            '200': { description: 'User info' },
            '401': { description: 'Unauthorized' },
          },
        },
      },
      '/rides': {
        get: {
          tags: ['Rides'],
          summary: 'Get list of rides',
          parameters: [
            { name: 'page', in: 'query', schema: { type: 'integer' } },
            { name: 'pageSize', in: 'query', schema: { type: 'integer' } },
            { name: 'status', in: 'query', schema: { type: 'string' } },
          ],
          responses: {
            '200': { description: 'List of rides' },
          },
        },
        post: {
          tags: ['Rides'],
          summary: 'Create a new ride',
          requestBody: {
            content: {
              'application/json': {
                schema: {
                  type: 'object',
                  properties: {
                    title: { type: 'string' },
                    startTime: { type: 'string', format: 'date-time' },
                  },
                },
              },
            },
          },
          responses: {
            '201': { description: 'Ride created' },
          },
        },
      },
      '/rides/{id}': {
        get: {
          tags: ['Rides'],
          summary: 'Get ride by ID',
          parameters: [
            { name: 'id', in: 'path', required: true, schema: { type: 'string' } },
          ],
          responses: {
            '200': { description: 'Ride details' },
            '404': { description: 'Not found' },
          },
        },
      },
      '/stats/summary': {
        get: {
          tags: ['Stats'],
          summary: 'Get statistics summary',
          responses: {
            '200': { description: 'Statistics summary' },
          },
        },
      },
    },
  };

  app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerDocument, {
    customCss: '.swagger-ui .topbar { display: none }',
    customSiteTitle: 'RideRecord API Docs',
  }));
}

export default setupSwagger;
