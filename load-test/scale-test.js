import http from 'k6/http';
import { check, sleep } from 'k6';

// ALB 주소는 실행할 때 -e로 주입 (지난번 placeholder 실수 방지!)
const BASE = `http://${__ENV.ALB_DNS}`;

export const options = {
    stages: [
      { duration: '1m', target: 100 },  // 빠르게 복귀
      { duration: '10m', target: 250 }, // 강도 2.5배
      { duration: '1m', target: 0 },
    ],
    thresholds: {
      http_req_failed: ['rate<0.05'],
      http_req_duration: ['p(95)<3000'], // 고부하라 응답 느려지는 건 정상
    },
  };

export default function () {
  check(http.get(`${BASE}/members`), { 'members 200': (r) => r.status === 200 });
  check(http.get(`${BASE}/health`), { 'health 200': (r) => r.status === 200 });
  sleep(0.1);
}