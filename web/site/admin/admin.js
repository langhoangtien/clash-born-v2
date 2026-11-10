// D-334: trang quản trị Clashborn — tìm tài khoản, ban / bỏ ban, đổi tên, xóa trận, nhật ký. Mã quản trị chỉ lưu trong
// trình duyệt này (localStorage) và gửi qua header Authorization tới /api/admin/*.
"use strict";

const KEY = "clashborn_admin_token";
const $ = (s) => document.querySelector(s);
const esc = (s) => String(s ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]);
const clock = (s) => Math.floor(s / 60) + ":" + String(Math.round(s % 60)).padStart(2, "0");
let token = "";
let current = 0;

function say(text, bad = false) {
  $("#msg").textContent = text;
  $("#msg").style.color = bad ? "#e07a6a" : "";
}

async function api(method, path, body) {
  const r = await fetch("/api/admin/" + path, {
    method, headers: { "Authorization": "Bearer " + token, "Content-Type": "application/json" },
    body: body ? JSON.stringify(body) : undefined,
  });
  const data = await r.json().catch(() => ({}));
  if (r.status === 401) { signOut(); throw new Error("Sai mã quản trị"); }
  if (!r.ok) throw new Error(data.error || "Lỗi " + r.status);
  return data;
}

function signOut() {
  try { localStorage.removeItem(KEY); } catch (e) { /* trình duyệt chặn lưu */ }
  token = "";
  $("#app").hidden = true;
  $("#login").hidden = false;
}

async function search() {
  const q = $("#q").value.trim();
  const { accounts } = await api("GET", "accounts?q=" + encodeURIComponent(q));
  $("#accounts tbody").innerHTML = accounts.length ? accounts.map((a) => `<tr data-id="${a.id}">
    <td>${a.id}</td><td>${esc(a.name) || "<span class='muted'>(chưa đặt)</span>"}</td><td>${esc(a.email)}</td>
    <td class="num">${a.games}</td><td>${a.banned ? "<span class='banned'>Đã ban</span>" : "<span class='ok'>Hoạt động</span>"}</td>
    </tr>`).join("") : `<tr><td colspan="5" class="empty">Không có tài khoản nào.</td></tr>`;
}

async function open(id) {
  current = id;
  const a = await api("GET", "account/" + id);
  const box = $("#detail");
  box.hidden = false;
  const rows = a.matches.map((m) => `<tr><td>${m.match}</td><td>${esc(m.at.slice(0, 16).replace("T", " "))}</td>
    <td>${esc(m.mode)} · ${esc(m.kind)}</td><td>${esc(m.hero)}</td><td class="${m.won ? "ok" : "banned"}">${m.won ? "Thắng" : "Thua"}</td>
    <td class="num">${m.kills}/${m.deaths}/${m.assists}</td><td class="num">${clock(m.duration_s)}</td>
    <td><button class="ghost" data-match="${m.match}">Xóa trận</button></td></tr>`).join("");
  box.innerHTML = `<h2>#${a.id} ${esc(a.name) || "(chưa đặt tên)"}</h2>
    <p class="facts">${esc(a.email)} · tạo ${esc(a.created)} · ${a.google ? "Google" : ""}${a.google && a.password ? " + " : ""}${a.password ? "mật khẩu" : ""}
      · ${a.games} trận${a.banned ? ` · <span class="banned">ĐÃ BAN: ${esc(a.ban_reason)}</span>` : ""}</p>
    <div class="actions">
      ${a.banned ? `<button data-act="unban">Bỏ ban</button>` : `<button class="danger" data-act="ban">Ban</button>`}
      <button class="ghost" data-act="rename">Đổi tên</button>
      <button class="danger" data-act="delete_matches">Xóa mọi trận (${a.games})</button>
    </div>
    <table class="grid">${rows || "<tr><td class='empty'>Chưa có trận nào.</td></tr>"}</table>`;
}

async function act(what) {
  const body = { id: current };
  if (what === "ban") {
    const reason = prompt("Lý do ban (người chơi sẽ thấy):", "Gian lận");
    if (reason === null) return;
    body.reason = reason;
  } else if (what === "rename") {
    const name = prompt("Tên mới (3–16 ký tự):");
    if (!name) return;
    body.name = name;
  } else if (what === "delete_matches" && !confirm("Xóa mọi trận của tài khoản này khỏi thống kê? Không hoàn tác được.")) {
    return;
  }
  await api("POST", what, body);
  say("Đã làm: " + what);
  await Promise.all([open(current), search(), loadLog()]);
}

async function dropMatch(id) {
  if (!confirm("Xóa trận " + id + " khỏi thống kê?")) return;
  await api("POST", "delete_match", { match: Number(id) });
  say("Đã xóa trận " + id);
  await Promise.all([open(current), loadLog()]);
}

async function loadLog() {
  const { log } = await api("GET", "log");
  $("#log tbody").innerHTML = log.length ? log.map((e) => `<tr><td>${esc(e.at.replace("T", " ").slice(0, 16))}</td>
    <td>${esc(e.action)}</td><td>${esc(e.target)}</td><td class="wrap">${esc(e.detail)}</td></tr>`).join("")
    : `<tr><td class="empty">Chưa có thao tác nào.</td></tr>`;
}

async function start() {
  $("#login").hidden = true;
  $("#app").hidden = false;
  try { await Promise.all([search(), loadLog()]); say(""); } catch (e) { say(e.message, true); }
}

const guard = (fn) => async (...a) => { try { await fn(...a); } catch (e) { say(e.message, true); } };

$("#login").addEventListener("submit", (e) => {
  e.preventDefault();
  token = $("#token").value.trim();
  try { localStorage.setItem(KEY, token); } catch (err) { /* trình duyệt chặn lưu: chỉ dùng trong phiên này */ }
  start();
});
$("#search").addEventListener("submit", (e) => { e.preventDefault(); guard(search)(); });
$("#logout").addEventListener("click", signOut);
$("#accounts tbody").addEventListener("click", (e) => { const tr = e.target.closest("tr[data-id]"); if (tr) guard(open)(Number(tr.dataset.id)); });
$("#detail").addEventListener("click", (e) => {
  const b = e.target.closest("button");
  if (b && b.dataset.act) guard(act)(b.dataset.act);
  if (b && b.dataset.match) guard(dropMatch)(b.dataset.match);
});

try { token = localStorage.getItem(KEY) || ""; } catch (e) { token = ""; }
if (token) start(); else $("#login").hidden = false;
