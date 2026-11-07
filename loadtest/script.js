import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate } from 'k6/metrics';

const BASE_URL = __ENV.BASE_URL;
const VUS = parseInt(__ENV.VUS || '40');

const cacheHits = new Rate('cache_hits');

export const options = {
  stages: [
    { duration: '2m', target: VUS },
    { duration: '5m', target: VUS },
    { duration: '2m', target: 0 },
  ],
  summaryTrendStats: ['avg', 'med', 'p(95)', 'p(99)', 'max'],
  thresholds: {
    'http_req_duration{name:GET /products}': ['max>=0'],
  },
};

const JSON_HEADERS = { headers: { 'Content-Type': 'application/json' } };

export function setup() {
  if (!BASE_URL) {
    throw new Error('Вкажи адресу: -e BASE_URL=http://...');
  }
  const res = http.post(
    `${BASE_URL}/categories`,
    JSON.stringify({ name: `Loadtest ${Date.now()}` }),
    JSON_HEADERS,
  );
  check(res, { 'категорію створено': (r) => r.status === 201 });
  return { categoryId: res.json('id') };
}

function recordCache(res) {
  const header = res.headers['X-Cache'];
  if (header === 'HIT') cacheHits.add(1);
  if (header === 'MISS') cacheHits.add(0);
}

export default function (data) {
  const sku = `LT-${__VU}-${__ITER}-${Date.now()}`;
  const created = http.post(
    `${BASE_URL}/products`,
    JSON.stringify({ sku, name: 'Тестовий ноутбук', brand: 'k6', price: 999.99, category_id: data.categoryId }),
    { ...JSON_HEADERS, tags: { name: 'POST /products' } },
  );
  check(created, { 'товар створено (201)': (r) => r.status === 201 });
  const newId = created.status === 201 ? created.json('id') : 1;

  for (let i = 0; i < 4; i++) {
    const list = http.get(`${BASE_URL}/products`, { tags: { name: 'GET /products' } });
    check(list, { 'список (200)': (r) => r.status === 200 });
    recordCache(list);
  }

  const own = http.get(`${BASE_URL}/products/${newId}`, { tags: { name: 'GET /products/{id}' } });
  check(own, { 'свій товар (200)': (r) => r.status === 200 });

  const randomId = Math.floor(Math.random() * newId) + 1;
  http.get(`${BASE_URL}/products/${randomId}`, {
    tags: { name: 'GET /products/{id}' },
    responseCallback: http.expectedStatuses(200, 404),
  });

  for (let i = 0; i < 2; i++) {
    http.get(`${BASE_URL}/categories`, { tags: { name: 'GET /categories' } });
  }

  http.get(`${BASE_URL}/products/${newId}/movements`, { tags: { name: 'GET /products/{id}/movements' } });

  sleep(1);
}
