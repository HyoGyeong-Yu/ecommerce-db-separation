import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  stages: [
    { duration: '30s', target: 20 },  // 30초 동안 가상유저 20명까지 증가
    { duration: '1m', target: 20 },   // 1분 유지
    { duration: '30s', target: 0 },   // 30초 동안 감소
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'], // 95% 요청이 500ms 안에
    http_req_failed: ['rate<0.01'],   // 실패율 1% 미만
  },
};

const BASE = 'http://localhost:8000';

export default function () {
  const endpoints = [
    `${BASE}/members`,
    `${BASE}/payments`,
    `${BASE}/cart/1`,
  ];

  // 3개 도메인에 골고루 요청
  for (const url of endpoints) {
    const res = http.get(url);
    check(res, { 'status is 200': (r) => r.status === 200 });
  }
  sleep(1);
}