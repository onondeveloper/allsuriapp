import type { Handler } from '@netlify/functions'

export const handler: Handler = async (event) => {
  const SUPABASE_URL = process.env.SUPABASE_URL
  const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY
  const JWT_SECRET = process.env.JWT_SECRET
  
  return {
    statusCode: 200,
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      env_check: {
        SUPABASE_URL: SUPABASE_URL ? `설정됨 (${SUPABASE_URL.substring(0, 30)}...)` : '❌ 없음',
        SUPABASE_SERVICE_ROLE_KEY: SUPABASE_SERVICE_ROLE_KEY ? `설정됨 (${SUPABASE_SERVICE_ROLE_KEY.substring(0, 20)}...)` : '❌ 없음',
        JWT_SECRET: JWT_SECRET ? `설정됨 (${JWT_SECRET.substring(0, 10)}...)` : '❌ 없음',
      },
      timestamp: new Date().toISOString(),
    })
  }
}

