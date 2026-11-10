// D-334 / D-335: trang quản trị Clashborn — đăng nhập bằng tài khoản game có quyền Điều hành (mod) / Quản trị (admin), hoặc
// mã quản trị dự phòng; tìm tài khoản, ban / bỏ ban, đổi tên, xóa trận, cấp quyền (admin), nhật ký. Phiên / mã chỉ lưu trong
// trình duyệt này (localStorage).
"use strict";

const KEY = "clashborn_admin";            // {kind: "session" | "master", value}
const ROLE = { "": "Người chơi", mod: "Điều hành", admin: "Quản trị", master: "Mã quản trị" };
const RANK = { "": 0, mod: 1, admin: 2, master: 3 };
const $ = (s) => document.querySelector(s);
const esc = (s) => String(s ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]);
const clock = (s) => Math.floor(s / 60) + ":" + String(Math.round(s % 60)).padStart(2, "0");
let auth = null;
let me = { role: "" };
let current = 0;

function say(text, bad = false) {
  $("#msg").textContent = text;
  $("#msg").style.color = bad ? "#e07a6a" : "";
}

function headers() {
  const h = { "Content-Type": "application/json" };
  if (auth && auth.kind === "master") h["Authorization"] = "Bearer " + auth.value;
  if (auth && auth.kind === "session") h["X-Clashborn-Session"] = auth.value;
  return h;
}

async function call(url, method = "GET", body) {
  const r = await fetch(url, { method, headers: headers(), body: body ? JSON.stringify(body) : undefined });
  const data = await r.json().catch(() => ({}));
  return { ok: r.ok, status: r.status, data };
}

async function api(method, path, body) {
  const { ok, status, data } = await call("/api/admin/" + path, method, body);
  if (status === 401) { signOut(); throw new Error(data.error || "Hết phiên — đăng nhập lại"); }
  if (!ok) throw new Error(data.error || "Lỗi " + status);
  return data;
}

function remember(a) {
  auth = a;
  try { a ? localStorage.setItem(KEY, JSON.stringify(a)) : localStorage.removeItem(KEY); } catch (e) { /* bị chặn lưu */ }
}

function signOut() {
  if (auth && auth.kind === "session") call("/api/auth/logout", "POST", {});
  remember(null);
  $("#app").hidden = true;
  $("#login").hidden = false;
}

async function search() {
  const { accounts } = await api("GET", "accounts?q=" + encodeURIComponent($("#q").value.trim()));
  $("#accounts tbody").innerHTML = accounts.length ? accounts.map((a) => `<tr data-id="${a.id}">
    <td>${a.id}</td><td>${esc(a.name) || "<span class='muted'>(chưa đặt)</span>"}</td><td>${esc(a.email)}</td>
    <td>${a.role ? `<span class="role">${ROLE[a.role]}</span>` : ""}</td><td class="num">${a.games}</td>
    <td>${a.banned ? "<span class='banned'>Đã ban</span>" : "<span class='ok'>Hoạt động</span>"}</td></tr>`).join("")
    : `<tr><td colspan="6" class="empty">Không có tài khoản nào.</td></tr>`;
}

function roleControl(a) {
  if (RANK[me.role] < RANK.admin || RANK[a.role] >= RANK[me.role] || a.id === me.id) return "";
  const opts = ["", "mod", "admin"].filter((r) => RANK[r] <= RANK[me.role])
    .map((r) => `<option value="${r}" ${r === a.role ? "selected" : ""}>${ROLE[r]}</option>`).join("");
  return `<label class="inline">Quyền <select id="role">${opts}</select></label>`;
}

async function open(id) {
  current = id;
  const a = await api("GET", "account/" + id);
  const canAct = RANK[a.role] < RANK[me.role] && a.id !== me.id;
  const box = $("#detail");
  box.hidden = false;
  const rows = a.matches.map((m) => `<tr><td>${m.match}</td><td>${esc(m.at.slice(0, 16).replace("T", " "))}</td>
    <td>${esc(m.mode)} · ${esc(m.kind)}</td><td>${esc(m.hero)}</td><td class="${m.won ? "ok" : "banned"}">${m.won ? "Thắng" : "Thua"}</td>
    <td class="num">${m.kills}/${m.deaths}/${m.assists}</td><td class="num">${clock(m.duration_s)}</td>
    <td><button class="ghost" data-match="${m.match}">Xóa trận</button></td></tr>`).join("");
  box.innerHTML = `<h2>#${a.id} ${esc(a.name) || "(chưa đặt tên)"} ${a.role ? `<span class="role">${ROLE[a.role]}</span>` : ""}</h2>
    <p class="facts">${esc(a.email)} · tạo ${esc(a.created)} · ${[a.google ? "Google" : "", a.password ? "mật khẩu" : ""].filter(Boolean).join(" + ")}
      · ${a.games} trận${a.banned ? ` · <span class="banned">ĐÃ BAN: ${esc(a.ban_reason)}</span>` : ""}</p>
    <div class="actions">${canAct ? `
      ${a.banned ? `<button data-act="unban">Bỏ ban</button>` : `<button class="danger" data-act="ban">Ban</button>`}
      <button class="ghost" data-act="rename">Đổi tên</button>
      <button class="danger" data-act="delete_matches">Xóa mọi trận (${a.games})</button>
      ${roleControl(a)}` : `<span class="muted">Tài khoản cùng cấp / cao hơn hoặc của chính bạn — chỉ xem.</span>`}</div>
    <table class="grid">${rows || "<tr><td class='empty'>Chưa có trận nào.</td></tr>"}</table>`;
}

async function act(what, extra = {}) {
  const body = { id: current, ...extra };
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
    <td>${esc(e.actor)}</td><td>${esc(e.action)}</td><td>${esc(e.target)}</td><td class="wrap">${esc(e.detail)}</td></tr>`).join("")
    : `<tr><td class="empty">Chưa có thao tác nào.</td></tr>`;
}

async function start() {
  try {
    me = await api("GET", "whoami");
    if (auth.kind === "session") me.id = (await call("/api/auth/me")).data.id;
    $("#whoami").textContent = `Đang dùng: ${me.name || "(chưa đặt tên)"} — ${ROLE[me.role]}`;
    $("#login").hidden = true;
    $("#app").hidden = false;
    await Promise.all([search(), loadLog()]);
    say("");
  } catch (e) {
    say(e.message, true);
  }
}

async function signIn(token) {
  remember({ kind: "session", value: token });
  await start();
}

async function google() {
  const { ok, data } = await call("/api/auth/google/start", "POST", {});
  if (!ok) { say(data.error || "Không mở được Google", true); return; }
  window.open(data.url, "_blank");
  say("Đăng nhập Google ở thẻ mới rồi quay lại đây…");
  for (let i = 0; i < 300; i++) {
    await new Promise((r) => setTimeout(r, 2000));
    const p = await call("/api/auth/google/poll", "POST", { sid: data.sid });
    if (p.ok && p.data.token) return signIn(p.data.token);
    if (!p.ok) { say(p.data.error || "Hết thời gian đăng nhập Google", true); return; }
  }
}

const guard = (fn) => async (...a) => { try { await fn(...a); } catch (e) { say(e.message, true); } };

$("#pw").addEventListener("submit", guard(async (e) => {
  e.preventDefault();
  const { ok, data } = await call("/api/auth/login", "POST", { email: $("#email").value.trim(), password: $("#password").value });
  if (!ok) { say(data.error || "Không đăng nhập được", true); return; }
  $("#password").value = "";
  await signIn(data.token);
}));
$("#google").addEventListener("click", guard(google));
$("#master").addEventListener("submit", (e) => {
  e.preventDefault();
  remember({ kind: "master", value: $("#token").value.trim() });
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
$("#detail").addEventListener("change", (e) => { if (e.target.id === "role") guard(act)("set_role", { role: e.target.value }); });

try { auth = JSON.parse(localStorage.getItem(KEY) || "null"); } catch (e) { auth = null; }
if (auth) start(); else $("#login").hidden = false;
