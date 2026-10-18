let categories = [];
let openHistoryId = null;

const $ = (id) => document.getElementById(id);

function el(tag, text, className) {
  const node = document.createElement(tag);
  if (text !== undefined) node.textContent = text;
  if (className) node.className = className;
  return node;
}

function showMessage(text) {
  const box = $("message");
  box.textContent = text;
  box.className = "message error";
  setTimeout(() => (box.className = "message hidden"), 5000);
}

async function api(path, options = {}) {
  const response = await fetch(path, {
    headers: { "Content-Type": "application/json" },
    ...options,
  });
  if (response.status === 204) return null;

  const data = await response.json().catch(() => ({}));
  if (!response.ok) {
    const detail = Array.isArray(data.detail)
      ? data.detail.map((item) => item.msg).join("; ")
      : data.detail;
    throw new Error(detail || "Request failed");
  }
  return data;
}

async function run(action) {
  try {
    await action();
  } catch (error) {
    showMessage(error.message);
  }
}

function fillSelect(select, withAll) {
  const current = select.value;
  select.replaceChildren();
  if (withAll) select.append(new Option("All categories", ""));
  for (const category of categories) {
    select.append(new Option(category.name, category.id));
  }
  if (Array.from(select.options).some((option) => option.value === current)) {
    select.value = current;
  }
}

function renderCategories() {
  const list = $("category-list");
  list.replaceChildren();
  for (const category of categories) {
    const item = el("li", category.name);
    const remove = el("button", "\u00d7");
    remove.title = "Delete category";
    remove.onclick = () =>
      run(async () => {
        await api(`/categories/${category.id}`, { method: "DELETE" });
        await loadCategories();
        await loadProducts();
      });
    item.append(remove);
    list.append(item);
  }
  fillSelect($("product-category"), false);
  fillSelect($("filter-category"), true);
}

async function loadCategories() {
  categories = await api("/categories");
  renderCategories();
}

function categoryName(id) {
  const category = categories.find((item) => item.id === id);
  return category ? category.name : "-";
}

function renderProducts(products) {
  const body = $("product-body");
  body.replaceChildren();
  for (const product of products) {
    const row = el("tr");
    row.append(
      el("td", product.sku),
      el("td", product.name),
      el("td", product.brand),
      el("td", categoryName(product.category_id)),
      el("td", product.price.toFixed(2), "num"),
      el("td", String(product.quantity), "num"),
    );

    const actions = el("td", undefined, "actions");
    const receive = el("button", "+ Receive");
    receive.onclick = () => moveStock(product, "receipt");
    const sell = el("button", "\u2212 Sell", "secondary");
    sell.onclick = () => moveStock(product, "sale");
    const history = el("button", "History", "secondary");
    history.onclick = () => run(() => showHistory(product));
    const remove = el("button", "Delete", "danger");
    remove.onclick = () => removeProduct(product);
    actions.append(receive, sell, history, remove);

    row.append(actions);
    body.append(row);
  }
}

async function loadProducts() {
  const params = new URLSearchParams({ limit: "200" });
  if ($("search").value) params.set("q", $("search").value);
  if ($("filter-category").value) {
    params.set("category_id", $("filter-category").value);
  }
  renderProducts(await api(`/products?${params}`));
}

async function showHistory(product) {
  const movements = await api(`/products/${product.id}/movements`);
  openHistoryId = product.id;
  $("history-title").textContent = `History: ${product.name}`;

  const body = $("history-body");
  body.replaceChildren();
  for (const movement of movements) {
    const row = el("tr");
    row.append(
      el("td", new Date(movement.created_at).toLocaleString()),
      el("td", movement.reason),
      el("td", String(movement.change), "num"),
    );
    body.append(row);
  }
  $("history-card").classList.remove("hidden");
}

function moveStock(product, reason) {
  const question =
    reason === "receipt" ? "How many units received?" : "How many units sold?";
  const input = prompt(question);
  if (input === null) return;

  const amount = Number(input);
  if (!Number.isInteger(amount) || amount <= 0) {
    showMessage("Enter a positive whole number");
    return;
  }

  const change = reason === "sale" ? -amount : amount;
  run(async () => {
    await api(`/products/${product.id}/movements`, {
      method: "POST",
      body: JSON.stringify({ change, reason }),
    });
    await loadProducts();
    if (openHistoryId === product.id) await showHistory(product);
  });
}

function removeProduct(product) {
  if (!confirm(`Delete "${product.name}" with its history?`)) return;
  run(async () => {
    await api(`/products/${product.id}`, { method: "DELETE" });
    if (openHistoryId === product.id) {
      openHistoryId = null;
      $("history-card").classList.add("hidden");
    }
    await loadProducts();
  });
}

$("category-form").addEventListener("submit", (event) => {
  event.preventDefault();
  run(async () => {
    const name = $("category-name").value.trim();
    await api("/categories", { method: "POST", body: JSON.stringify({ name }) });
    $("category-form").reset();
    await loadCategories();
  });
});

$("product-form").addEventListener("submit", (event) => {
  event.preventDefault();
  run(async () => {
    const product = {
      sku: $("product-sku").value.trim(),
      name: $("product-name").value.trim(),
      brand: $("product-brand").value.trim(),
      price: $("product-price").value,
      category_id: Number($("product-category").value),
    };
    await api("/products", { method: "POST", body: JSON.stringify(product) });
    $("product-form").reset();
    await loadProducts();
  });
});

$("search").addEventListener("input", () => run(loadProducts));
$("filter-category").addEventListener("change", () => run(loadProducts));

run(async () => {
  const health = await api("/health");
  $("version").textContent = health.version.slice(0, 7);
  await loadCategories();
  await loadProducts();
});
