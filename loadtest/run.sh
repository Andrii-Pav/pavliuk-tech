set -euo pipefail

cd "$(dirname "$0")/.."
VUS="${1:-40}"
LABEL="${2:-run}"
BASE_URL="$(terraform -chdir=terraform output -raw app_url)"
STAMP="$(date +%Y%m%d-%H%M)"
mkdir -p loadtest/results

echo "Тест: $BASE_URL, N=$VUS, старт $(date +%H:%M:%S)"
k6 run -e BASE_URL="$BASE_URL" -e VUS="$VUS" \
  --summary-export "loadtest/results/${STAMP}-${LABEL}.json" \
  loadtest/script.js | tee "loadtest/results/${STAMP}-${LABEL}.txt"
echo "Кінець $(date +%H:%M:%S). Результати: loadtest/results/${STAMP}-${LABEL}.txt"
