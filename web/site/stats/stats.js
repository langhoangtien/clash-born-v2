// Clashborn Stats (D-331, ROADMAP ST.3): bảng tướng / đồ, trang tướng (đồ, đồ khởi đầu, khắc chế, hợp đội).
// Đọc API công khai /api/stats/* với bộ lọc mode / kind / version; tên + ảnh lấy từ ../heroes.json, ../items.json.
"use strict";

const API = "/api/stats/";
const FEW = 10;  // dưới chừng này trận: tỉ lệ hiện mờ
const state = { tab: "heroes", heroes: [], items: [], sort: { heroes: ["games", -1], items: ["games", -1] }, open: "" };
const names = { heroes: {}, items: {} };

const $ = (sel, root = document) => root.querySelector(sel);
const esc = (s) => String(s).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]);
const pct = (x) => (x * 100).toFixed(1) + "%";
const clock = (s) => Math.floor(s / 60) + ":" + String(Math.round(s % 60)).padStart(2, "0");

function query() {
  const f = new FormData($("#filters"));
  const q = new URLSearchParams();
  for (const [k, v] of f) if (v) q.set(k, v);
  return q.toString() ? "?" + q : "";
}

async function get(path) {
  const r = await fetch(API + path + query());
  if (!r.ok) throw new Error(r.status);
  return r.json();
}

function heroCell(id) {
  const h = names.heroes[id] || { name: id };
  return `<span class="who"><img src="../img/heroes/${esc(id)}.webp" alt="" loading="lazy" onerror="this.remove()">${esc(h.name.split(" · ")[0])}</span>`;
}

function itemCell(id) {
  const it = names.items[id] || { name: id };
  return `<span class="who"><img class="item" src="../img/items/${esc(id)}.webp" alt="" loading="lazy" onerror="this.remove()">${esc(it.name)}</span>`;
}

function rate(r) {
  const cls = r.games < FEW ? "few" : r.winrate >= 0.52 ? "up" : r.winrate <= 0.48 ? "down" : "";
  return `<span class="rate ${cls}"><span class="bar"><i style="width:${(r.winrate * 100).toFixed(1)}%"></i></span>${pct(r.winrate)}</span>`;
}

function sorted(rows, kind) {
  const [key, dir] = state.sort[kind];
  const val = (r) => key === "name" ? (names[kind][r.hero || r.item] || {}).name || r.hero || r.item
    : key === "kda" ? (r.kills + r.assists) / Math.max(1, r.deaths) : r[key];
  return [...rows].sort((a, b) => (val(a) > val(b) ? 1 : val(a) < val(b) ? -1 : 0) * dir);
}

function drawHeroes() {
  const body = $("#heroes tbody");
  if (!state.heroes.length) { body.innerHTML = `<tr><td colspan="6" class="empty">Chưa có trận nào với bộ lọc này.</td></tr>`; return; }
  body.innerHTML = sorted(state.heroes, "heroes").map((r) => `<tr data-hero="${esc(r.hero)}" class="${r.hero === state.open ? "on" : ""}">
    <td>${heroCell(r.hero)}</td><td class="num">${r.games}</td><td class="num">${rate(r)}</td>
    <td class="num">${pct(r.pickrate)}</td><td class="num">${r.kills.toFixed(1)} / ${r.deaths.toFixed(1)} / ${r.assists.toFixed(1)}</td>
    <td class="num wide">${r.level.toFixed(1)}</td></tr>`).join("");
}

function drawItems() {
  const body = $("#items tbody");
  if (!state.items.length) { body.innerHTML = `<tr><td colspan="4" class="empty">Chưa có trận nào với bộ lọc này.</td></tr>`; return; }
  body.innerHTML = sorted(state.items, "items").map((r) => `<tr><td>${itemCell(r.item)}</td><td class="num">${r.games}</td>
    <td class="num">${rate(r)}</td><td class="num">${r.first_buy_s ? clock(r.first_buy_s) : "—"}</td></tr>`).join("");
}

function mini(title, rows, cell) {
  const list = rows.slice(0, 8).map((r) => `<li>${cell(r)}<span class="n">${r.games} trận</span>${rate(r)}</li>`).join("");
  return `<div class="mini"><h3>${title}</h3>${list ? `<ul>${list}</ul>` : `<p class="muted">Chưa có.</p>`}</div>`;
}

async function openHero(id) {
  const box = $("#hero-detail");
  if (state.open === id) { state.open = ""; box.hidden = true; drawHeroes(); return; }
  state.open = id;
  drawHeroes();
  box.hidden = false;
  box.innerHTML = `<p class="muted">Đang tải…</p>`;
  try {
    const d = await get("hero/" + encodeURIComponent(id));
    box.innerHTML = `<h2>${heroCell(id)}</h2><div class="minis">
      ${mini("Đồ cuối trận", d.items, (r) => itemCell(r.item))}
      ${mini("Đồ khởi đầu (90 giây đầu)", d.start_items, (r) => itemCell(r.item))}
      ${mini("Đối đầu (tỉ lệ thắng của " + esc((names.heroes[id] || { name: id }).name.split(" · ")[0]) + ")", d.vs, (r) => heroCell(r.hero))}
      ${mini("Cùng đội", d.with, (r) => heroCell(r.hero))}</div>`;
    box.scrollIntoView({ behavior: "smooth", block: "nearest" });
  } catch (e) {
    box.innerHTML = `<p class="muted">Không tải được (${esc(e.message)}).</p>`;
  }
}

async function load() {
  try {
    const [sum, h, it] = await Promise.all([get("summary"), get("heroes"), get("items")]);
    state.heroes = h.heroes;
    state.items = it.items;
    const sel = $("select[name=version]");
    const keep = sel.value;
    sel.innerHTML = `<option value="">Tất cả</option>` + sum.versions.map((v) => `<option>${esc(v)}</option>`).join("");
    sel.value = keep;
    $("#summary").textContent = sum.matches
      ? `${sum.matches} trận · thời lượng trung bình ${clock(sum.avg_duration_s)}`
      : "Chưa có trận nào với bộ lọc này.";
  } catch (e) {
    $("#summary").textContent = "Không tải được số liệu (" + e.message + ").";
  }
  drawHeroes();
  drawItems();
  if (state.open) { const id = state.open; state.open = ""; openHero(id); }
}

function showTab(tab) {
  state.tab = tab;
  for (const t of ["heroes", "items"]) $("#tab-" + t).hidden = t !== tab;
  document.querySelectorAll("[data-tab]").forEach((a) => a.classList.toggle("active", a.dataset.tab === tab));
}

async function init() {
  const [hs, its] = await Promise.all([fetch("../heroes.json").then((r) => r.json()).catch(() => []),
    fetch("../items.json").then((r) => r.json()).catch(() => [])]);
  for (const h of hs) names.heroes[h.id] = h;
  for (const i of its) names.items[i.id] = i;
  $("#filters").addEventListener("change", load);
  document.querySelectorAll("[data-tab]").forEach((a) => a.addEventListener("click", (e) => { e.preventDefault(); showTab(a.dataset.tab); }));
  document.querySelectorAll("th[data-sort]").forEach((th) => th.addEventListener("click", () => {
    const kind = th.closest("table").id;
    const [key, dir] = state.sort[kind];
    state.sort[kind] = [th.dataset.sort, key === th.dataset.sort ? -dir : (th.dataset.sort === "name" ? 1 : -1)];
    kind === "heroes" ? drawHeroes() : drawItems();
  }));
  $("#heroes tbody").addEventListener("click", (e) => { const tr = e.target.closest("tr[data-hero]"); if (tr) openHero(tr.dataset.hero); });
  showTab("heroes");
  load();
}

init();
