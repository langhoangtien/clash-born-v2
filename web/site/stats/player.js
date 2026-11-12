// D-334: trang người chơi — tướng hay chơi + 20 trận gần nhất (theo tên trong game, công khai, không email).
"use strict";
const $ = (s) => document.querySelector(s);
const esc = (s) => String(s ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]);
const pct = (x) => (x * 100).toFixed(1) + "%";
const clock = (s) => Math.floor(s / 60) + ":" + String(Math.round(s % 60)).padStart(2, "0");
const names = { heroes: {}, items: {} };
const hero = (id) => `<span class="who"><img src="../img/heroes/${esc(id)}.webp" alt="" onerror="this.remove()">${esc((names.heroes[id] || { name: id }).name.split(" · ")[0])}</span>`;
// D-343: hai đội — chân dung nhỏ (D-405: người rớt giữa trận ghi "đã rời"), rê chuột xem tên / bot / K/D/A; ô của người chơi này có viền.
const face = (p) => `<img class="mini-hero${p.me ? " me" : ""}" title="${esc((names.heroes[p.hero] || { name: p.hero }).name.split(" · ")[0] +
  (p.bot ? " (bot)" : p.name ? " — " + p.name : "") + (p.left ? " (đã rời)" : "") + " · " + p.kills + "/" + p.deaths + "/" + p.assists)}" src="../img/heroes/${esc(p.hero)}.webp" alt="${esc(p.hero)}">`;
const teams = (m) => m.allies ? `<span class="lineup">${m.allies.map(face).join("")}<span class="vs">vs</span>${m.enemies.map(face).join("")}</span>` : "";
const item = (id) => `<img class="mini-item" title="${esc((names.items[id] || { name: id }).name)}" src="../img/items/${esc(id)}.webp" alt="" onerror="this.remove()">`;

async function load(name) {
  $("#who").textContent = name || "Người chơi";
  if (!name) { $("#summary").textContent = "Nhập tên trong game để xem."; return; }
  const r = await fetch("/api/stats/player/" + encodeURIComponent(name));
  if (!r.ok) { $("#summary").textContent = "Không có người chơi này."; $("#heroes tbody").innerHTML = ""; $("#matches tbody").innerHTML = ""; return; }
  const p = await r.json();
  $("#who").textContent = p.name;
  document.title = p.name + " · Clashborn Stats";
  $("#summary").textContent = `${p.games} trận · thắng ${p.wins} (${pct(p.winrate)})`;
  $("#heroes tbody").innerHTML = p.heroes.map((h) => `<tr><td>${hero(h.hero)}</td><td class="num">${h.games}</td>
    <td class="num">${pct(h.winrate)}</td><td class="num">${h.kills}/${h.deaths}/${h.assists}</td></tr>`).join("")
    || `<tr><td colspan="4" class="empty">Chưa có trận nào.</td></tr>`;
  $("#matches tbody").innerHTML = p.matches.map((m) => `<tr><td>${hero(m.hero)}</td>
    <td class="${m.won ? "win" : "loss"}">${m.won ? "Thắng" : "Thua"}${m.left ? " (đã rời)" : ""}</td><td class="num">${m.kills}/${m.deaths}/${m.assists}</td>
    <td>${teams(m)}</td><td class="wide">${m.items.map(item).join("")}</td><td class="num wide">${clock(m.duration_s)}</td><td class="num">${esc(m.mode)}</td></tr>`).join("")
    || `<tr><td colspan="7" class="empty">Chưa có trận nào.</td></tr>`;
}

async function init() {
  const [hs, its] = await Promise.all([fetch("../heroes.json").then((r) => r.json()).catch(() => []),
    fetch("../items.json").then((r) => r.json()).catch(() => [])]);
  for (const h of hs) names.heroes[h.id] = h;
  for (const i of its) names.items[i.id] = i;
  const name = new URLSearchParams(location.search).get("name") || "";
  $("#find [name=name]").value = name;
  load(name);
}
init();
