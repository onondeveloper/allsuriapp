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

  return {
    statusCode: 200,
    headers,
    body: JSON.stringify({
      provider,
      openaiKeyPresent: !!openaiKey,
      openrouterKeyPresent: !!orKey,
      openaiModel: process.env.OPENAI_MODEL || 'gpt-4o-mini',
      openrouterModel: process.env.OPENROUTER_MODEL || 'meta-llama/llama-3.1-8b-instruct:free',
      timestamp: new Date().toISOString(),
    }),
  };
};

export { handler };

