import swaggerJSDoc from 'swagger-jsdoc';

export const swaggerSpec = swaggerJSDoc({
  definition: {
    openapi: '3.0.3',
    info: {
      title: 'AI Recruiter API',
      version: '0.1.0',
    },
    // Use relative server URL so Swagger requests go to the same host you opened (/docs),
    // avoiding localhost vs 127.0.0.1 origin mismatches.
    servers: [{ url: '/' }],
    components: {
      securitySchemes: {
        bearerAuth: {
          type: 'http',
          scheme: 'bearer',
          bearerFormat: 'JWT',
        },
      },
    },
    security: [{ bearerAuth: [] }],
  },
  apis: ['src/routes/**/*.ts'],
});
