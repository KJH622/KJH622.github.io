/**
 * 블로그 사이드바 방문자 수 (전체 · 오늘 · 어제)
 *
 * 왜 만들었나
 *   GoatCounter 의 공개 카운터는 응답을 최대 4시간 캐시한다.
 *   「오늘」이 몇 시간씩 안 움직여서 직접 만들었다. 이건 실시간이다.
 *
 * 무엇을 세는가
 *   페이지를 열 때마다가 아니라 **하루에 한 사람 한 번**만 센다.
 *   - 티스토리 사이드바의 「방문자 수」와 같은 뜻이다 (조회수가 아니다)
 *   - KV 쓰기가 무료 한도(하루 1,000)에 걸리지 않게 하는 이유이기도 하다
 *   「오늘 이미 셌는지」는 브라우저가 기억한다. 서버에는 아무것도 남기지 않는다.
 *
 * KV 에 들어가는 것
 *   total            전체 누적
 *   day:YYYY-MM-DD   그날 방문자 수
 *
 * 날짜 기준
 *   한국 시간(KST, UTC+9). Worker 는 UTC 로 돌기 때문에 9시간을 더해서 날짜를 만든다.
 *   안 그러면 한국 기준 오전 9시에 날짜가 바뀐다.
 */

const KST_OFFSET = 9 * 60 * 60 * 1000;

function kstDate(shiftDays = 0) {
  const t = Date.now() + KST_OFFSET + shiftDays * 86400000;
  return new Date(t).toISOString().slice(0, 10); // YYYY-MM-DD
}

function corsHeaders(origin) {
  // 이 블로그에서만 부를 수 있게 한다. 다른 사이트가 숫자를 올리지 못하게.
  const allowed = ['https://kjh622.github.io'];
  return {
    'Access-Control-Allow-Origin': allowed.includes(origin) ? origin : allowed[0],
    'Access-Control-Allow-Methods': 'GET, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
    'Cache-Control': 'no-store'
  };
}

async function readCounts(kv) {
  const today = kstDate(0);
  const yday = kstDate(-1);
  const [total, t, y] = await Promise.all([
    kv.get('total'),
    kv.get('day:' + today),
    kv.get('day:' + yday)
  ]);
  return {
    total: Number(total) || 0,
    today: Number(t) || 0,
    yesterday: Number(y) || 0
  };
}

export default {
  async fetch(request, env) {
    const origin = request.headers.get('Origin') || '';
    const headers = { 'Content-Type': 'application/json; charset=utf-8', ...corsHeaders(origin) };

    if (request.method === 'OPTIONS') {
      return new Response(null, { headers });
    }

    const url = new URL(request.url);

    // ?hit=1 이면 숫자를 올린다. 없으면 읽기만 한다.
    // 사이드바는 「오늘 처음 온 사람」일 때만 hit=1 을 붙인다.
    if (url.searchParams.get('hit') === '1') {
      const today = kstDate(0);
      const dayKey = 'day:' + today;

      const [totalRaw, dayRaw] = await Promise.all([
        env.COUNTER.get('total'),
        env.COUNTER.get(dayKey)
      ]);

      const total = (Number(totalRaw) || 0) + 1;
      const day = (Number(dayRaw) || 0) + 1;

      await Promise.all([
        env.COUNTER.put('total', String(total)),
        // 그날 값은 90일 뒤 자동 삭제. 옛 날짜가 계속 쌓이지 않게.
        env.COUNTER.put(dayKey, String(day), { expirationTtl: 60 * 60 * 24 * 90 })
      ]);
    }

    const counts = await readCounts(env.COUNTER);
    return new Response(JSON.stringify(counts), { headers });
  }
};
