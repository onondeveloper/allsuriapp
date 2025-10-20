// OpenRouter 키 테스트 스크립트
// 사용법: node test_openrouter.js YOUR_API_KEY

const apiKey = process.argv[2];

if (!apiKey) {
  console.log('❌ API 키를 입력하세요: node test_openrouter.js YOUR_API_KEY');
  process.exit(1);
}

if (!apiKey.startsWith('sk-or-')) {
  console.log('❌ OpenRouter 키 형식이 올바르지 않습니다. sk-or-로 시작해야 합니다.');
  process.exit(1);
}

async function testOpenRouter() {
  try {
    const response = await fetch('https://openrouter.ai/api/v1/models', {
      headers: {
        'Authorization': `Bearer ${apiKey}`,
        'HTTP-Referer': 'https://allsuri.app',
        'X-Title': 'Allsuri AI',
      },
    });

    if (response.ok) {
      const data = await response.json();
      console.log('✅ OpenRouter 키가 유효합니다!');
      console.log(`📊 사용 가능한 모델 수: ${data.data?.length || 0}`);
    } else {
      const error = await response.text();
      console.log('❌ OpenRouter 키 오류:', response.status, error);
    }
  } catch (error) {
    console.log('❌ 네트워크 오류:', error.message);
  }
}

testOpenRouter();
