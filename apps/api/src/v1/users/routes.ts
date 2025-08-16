import { FastifyInstance } from 'fastify';
import { problem } from '../../lib/problem.js';

export default async function usersRoutes(fastify: FastifyInstance) {
  
  // GET /v1/users/profile
  // Returns current user profile information
  fastify.get('/profile', {
    schema: {
      description: 'Get current user profile',
      tags: ['users'],
      headers: {
        type: 'object',
        required: ['authorization'],
        properties: {
          authorization: { type: 'string', description: 'Bearer token' }
        }
      },
      response: {
        200: {
          type: 'object',
          properties: {
            id: { type: 'string' },
            email: { type: 'string' },
            name: { type: 'string', nullable: true },
            provider: { type: 'string' },
            created_at: { type: 'string' },
            isVerified: { type: 'boolean' }
          }
        }
      }
    }
  }, async (req, reply) => {
    // For now, return mock user data for development
    // In a real implementation, this would extract user ID from JWT and fetch from database
    
    const authHeader = req.headers.authorization;
    if (!authHeader?.startsWith('Bearer ')) {
      return reply.code(401).type('application/problem+json').send(
        problem(401, 'unauthorized', 'Invalid or missing authorization header', 'urn:thankful:auth:invalid_token', req.ctx?.traceId)
      );
    }
    
    const token = authHeader.substring(7);
    
    // Mock user profile for development
    // TODO: Implement proper JWT verification and user lookup
    const mockUser = {
      id: 'user_development_123',
      email: 'dev@lastminutelive.com',
      name: 'Development User',
      provider: 'email',
      created_at: new Date().toISOString(),
      isVerified: true
    };
    
    return reply.code(200).send(mockUser);
  });
  
  // POST /v1/users/refresh
  // Refresh access token using refresh token
  fastify.post('/refresh', {
    schema: {
      description: 'Refresh access token',
      tags: ['users'],
      body: {
        type: 'object',
        required: ['refresh_token'],
        properties: {
          refresh_token: { type: 'string' }
        }
      },
      response: {
        200: {
          type: 'object',
          properties: {
            access_token: { type: 'string' },
            refresh_token: { type: 'string' },
            expires_at: { type: 'string' },
            user_id: { type: 'string' }
          }
        }
      }
    }
  }, async (req, reply) => {
    const body = req.body as { refresh_token: string };
    
    // Mock token refresh for development
    // TODO: Implement proper refresh token validation and new token generation
    
    const newTokens = {
      access_token: `mock_access_token_${Date.now()}`,
      refresh_token: `mock_refresh_token_${Date.now()}`,
      expires_at: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString(), // 24 hours
      user_id: 'user_development_123'
    };
    
    return reply.code(200).send(newTokens);
  });
}
