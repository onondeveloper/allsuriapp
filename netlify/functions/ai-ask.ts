import type { Handler, HandlerEvent, HandlerContext } from "@netlify/functions";

const isDomainQuestion = (text: string): boolean => {
  if (!text) return false;
  const q = (text || '').toLowerCase();
  const keywords = [
    '배관', '누수', '변기', '세면대', '싱크대', '수도', '수전', '보일러', '난방', '라디에터',
    '배수', '배수구', '하수구', '트랩', '방수', '실리콘', '곰팡이', '결로',
    '욕실', '타일', '샤워부스', '욕조', '환풍기',
    '주방', '현관', '타일', '도배', '장판', '목공', '도장',
    '시공', '공사', '리모델링', '인테리어', '견적', '자재', '철거'
  ];
  return keywords.some((k) => q.includes(k));
};

const handler: Handler = async (event: HandlerEvent, context: HandlerContext) => {
  // CORS headers
  const headers = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Content-Type': 'application/json',
  };

  // Handle preflight
  if (event.httpMethod === 'OPTIONS') {
    return { statusCode: 204, headers, body: '' };
  }

  if (event.httpMethod !== 'POST') {
    return {
      statusCode: 405,
      headers,
      body: JSON.stringify({ message: 'Method not allowed' }),
    };
  }

  try {
    const body = JSON.parse(event.body || '{}');
    const { question } = body;
    const images = Array.isArray(body?.images)
      ? body.images.filter((u: any) => typeof u === 'string' && u.trim().length > 0)
      : [];

    if (!question || typeof question !== 'string' || question.trim().length === 0) {
      return {
        statusCode: 400,
        headers,
        body: JSON.stringify({ message: '질문을 입력하세요.' }),
      };
    }

    const systemPromptBase = process.env.AI_SYSTEM_PROMPT || 
      'You are AllSuri AI, a helpful assistant for plumbing, leakage, bathroom renovation, and construction Q&A in Korean. Be concise and practical. If cost is requested, provide reasonable ranges in KRW with assumptions.';
    const domainGuard = process.env.AI_DOMAIN_GUARD || 
      'AllSuri AI는 설비, 누수, 욕실 리모델링, 건설 관련 질문에만 답합니다. 범위를 벗어난 일반 대화, 코딩, 번역, 시사 등은 정중히 거절하고 다른 일반 AI 도구 사용을 간단히 안내하세요. 모든 답변은 한국어로 간결하고 실용적으로 제공하세요.';
    const systemPrompt = `${systemPromptBase}\n\nDomain policy: ${domainGuard}`;

    // 도메인 외 질문 차단 및 안내
    if (!isDomainQuestion(question) && images.length === 0) {
      const guidance = 'AllSuri AI는 설비/인테리어 관련 상담 전용입니다. 일반 대화나 다른 주제는 ChatGPT 등 일반 AI 도구를 이용해 주세요. 설비·누수·욕실 리모델링·시공 관련 질문을 주시면 빠르게 도와드릴게요!';
      return {
        statusCode: 200,
        headers,
        body: JSON.stringify({ answer: guidance }),
      };
    }

    const openaiKey = process.env.OPENAI_API_KEY || '';
    const useOpenAI = !!openaiKey;

    if (useOpenAI) {
      // Prefer OpenAI when OPENAI_API_KEY is set
      const model = process.env.OPENAI_MODEL || 'gpt-4o-mini';
      const resp = await fetch('https://api.openai.com/v1/chat/completions', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${openaiKey}`,
        },
        body: JSON.stringify({
          model,
          messages: [
            { role: 'system', content: systemPrompt },
            {
              role: 'user',
              content: images.length > 0
                ? [
                    ...(question.trim().length > 0 ? [{ type: 'text', text: question.trim() }] : []),
                    ...images.map((url: string) => ({ type: 'image_url', image_url: { url } })),
                  ]
                : question.trim()
            },
          ],
          temperature: 0.3,
          max_tokens: 512,
        }),
      });

      if (!resp.ok) {
        const txt = await resp.text();
        try {
          const parsed = JSON.parse(txt);
          const errMsg = parsed?.error?.message || 'OpenAI 응답 오류';
          if (resp.status === 401) {
            return {
              statusCode: 401,
              headers,
              body: JSON.stringify({ message: 'OpenAI 키가 올바르지 않습니다.', details: errMsg }),
            };
          }
          if (resp.status === 429) {
            return {
              statusCode: 429,
              headers,
              body: JSON.stringify({ message: 'OpenAI 요청 한도를 초과했습니다. 잠시 후 다시 시도하세요.', details: errMsg }),
            };
          }
          return {
            statusCode: 502,
            headers,
            body: JSON.stringify({ message: 'OpenAI 응답 오류', details: errMsg }),
          };
        } catch (_) {
          return {
            statusCode: 502,
            headers,
            body: JSON.stringify({ message: 'OpenAI 응답 오류', details: txt }),
          };
        }
      }
      const data = await resp.json();
      const answer = data?.choices?.[0]?.message?.content || '';
      return {
        statusCode: 200,
        headers,
        body: JSON.stringify({ answer }),
      };
    }

    // Fallback to OpenRouter
    const orKey = process.env.OPENROUTER_API_KEY || '';
    const orModel = process.env.OPENROUTER_MODEL || 'meta-llama/llama-3.1-8b-instruct:free';
    if (!orKey) {
      return {
        statusCode: 503,
        headers,
        body: JSON.stringify({ message: 'AI 키가 설정되지 않았습니다. OPENAI_API_KEY 또는 OPENROUTER_API_KEY를 설정하세요.' }),
      };
    }

    if (images.length > 0) {
      return {
        statusCode: 501,
        headers,
        body: JSON.stringify({ message: '이미지 기반 질문은 현재 OpenAI 모델에서만 지원합니다. 텍스트 질문만 이용하거나 OpenAI 키를 설정하세요.' }),
      };
    }

    const resp = await fetch('https://openrouter.ai/api/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${orKey}`,
        'HTTP-Referer': process.env.OPENROUTER_REFERER || 'https://allsuri.app',
        'X-Title': process.env.OPENROUTER_TITLE || 'Allsuri AI',
      },
      body: JSON.stringify({
        model: orModel,
        messages: [
          { role: 'system', content: systemPrompt },
          { role: 'user', content: question.trim() },
        ],
        temperature: 0.3,
        max_tokens: 512,
      }),
    });

    if (!resp.ok) {
      const txt = await resp.text();
      try {
        const parsed = JSON.parse(txt);
        const code = parsed?.error?.code || parsed?.message?.code;
        const msg = parsed?.error?.message || parsed?.message || 'AI 응답 오류';
        if (code === 402 || /Insufficient credits/i.test(msg)) {
          return {
            statusCode: 402,
            headers,
            body: JSON.stringify({ message: 'AI 크레딧이 부족합니다. OpenRouter 크레딧 또는 키를 확인하세요.', details: msg }),
          };
        }
      } catch (_) {}
      return {
        statusCode: 502,
        headers,
        body: JSON.stringify({ message: 'AI 응답 오류', details: txt }),
      };
    }
    const data = await resp.json();
    const answer = data?.choices?.[0]?.message?.content || '';
    return {
      statusCode: 200,
      headers,
      body: JSON.stringify({ answer }),
    };
  } catch (e) {
    console.error('AI proxy error:', e);
    return {
      statusCode: 500,
      headers,
      body: JSON.stringify({ message: 'AI 요청 실패' }),
    };
  }
};

export { handler };

