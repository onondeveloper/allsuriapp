import type { Handler, HandlerEvent, HandlerContext } from '@netlify/functions'

const handler: Handler = async (event: HandlerEvent, context: HandlerContext) => {
  const headers = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type',
    'Access-Control-Allow-Methods': 'GET, OPTIONS',
    'Content-Type': 'application/json',
  };

  // Handle preflight
  if (event.httpMethod === 'OPTIONS') {
    return { statusCode: 204, headers, body: '' };
  }

  const openaiKey = process.env.OPENAI_API_KEY || '';
  const orKey = process.env.OPENROUTER_API_KEY || '';
  const useOpenAI = !!openaiKey;
  const provider = useOpenAI ? 'openai' : (orKey ? 'openrouter' : 'none');

  // 디버그 정보 추가
  const debugInfo = {
    provider,
    openaiKeyPresent: !!openaiKey,
    openrouterKeyPresent: !!orKey,
    openaiKeyLength: openaiKey.length,
    openrouterKeyLength: orKey.length,
    openaiKeyPrefix: openaiKey.substring(0, 8),
    openrouterKeyPrefix: orKey.substring(0, 8),
    openaiModel: process.env.OPENAI_MODEL || 'gpt-4o-mini',
    openrouterModel: process.env.OPENROUTER_MODEL || 'meta-llama/llama-3.1-8b-instruct:free',
    allEnvKeys: Object.keys(process.env).filter(k => k.includes('OPEN') || k.includes('AI')),
    timestamp: new Date().toISOString(),
  };

  return {
    statusCode: 200,
    headers,
    body: JSON.stringify(debugInfo),
  };
};

export { handler };

