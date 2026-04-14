
const fs = require('fs');
const jwt = require('jsonwebtoken');

const TEAM_ID = 'QPCC28T2SB';          // Apple Team ID
const KEY_ID = 'Q59ZM489XW';            // Apple Key ID
const CLIENT_ID = 'allsuriapp';    // Apple Services ID
const PRIVATE_KEY = fs.readFileSync('./AuthKey_Q59ZM489XW.p8', 'utf8');

const now = Math.floor(Date.now() / 1000);

const token = jwt.sign(
  {
    iss: TEAM_ID,
    iat: now,
    exp: now + 60 * 60 * 24 * 180,       // 최대 6개월 이내로 잡는 경우가 흔함
    aud: 'https://appleid.apple.com',
    sub: CLIENT_ID
  },
  PRIVATE_KEY,
  {
    algorithm: 'ES256',
    header: {
      alg: 'ES256',
      kid: KEY_ID
    }
  }
);

console.log(token);