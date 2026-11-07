// Clashborn — trang giới thiệu (D-284): thông tin bản mới nhất (version.json) và danh sách tướng (heroes.json).
"use strict";

function el(tag, attrs, text) {
  const n = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs || {})) n.setAttribute(k, v);
  if (text !== undefined) n.textContent = text;
  return n;
}

function megabytes(bytes) {
  return (bytes / 1048576).toFixed(0) + " MB";
}

async function showVersion() {
  const meta = document.querySelector("[data-meta]");
  try {
    const res = await fetch("version.json", { cache: "no-store" });
    if (!res.ok) throw new Error(res.status);
    const v = await res.json();
    const changed = res.headers.get("last-modified");
    const date = changed ? new Date(changed).toLocaleDateString("vi-VN") : "";
    const detail = [megabytes(v.size || 0), date && "cập nhật " + date].filter(Boolean).join(" · ");
    meta.textContent = "Bản " + v.name + " · " + detail;
    document.querySelector("[data-version]").textContent = "Bản " + v.name;
    document.querySelector("[data-detail]").textContent = detail;
    if (v.notes) document.querySelector("[data-notes]").textContent = v.notes;
  } catch (e) {
    meta.textContent = "Bản thử nghiệm cho Android";
  }
}

function heroCard(h) {
  const [name, title] = h.name.split(" · ");
  const card = el("details", { class: "hero-card" });
  const sum = el("summary");
  sum.append(el("img", { class: "portrait", src: "img/heroes/" + h.id + ".webp", alt: name, loading: "lazy" }));
  const info = el("div");
  info.append(el("h3", {}, name));
  if (title) info.append(el("div", { class: "title" }, title));
  info.append(el("span", { class: "pill" }, h.attribute));
  const icons = el("div", { class: "skill-icons" });
  for (const s of h.skills) icons.append(el("img", { src: "img/skills/" + s.icon + ".webp", alt: s.name, title: s.slot + " · " + s.name, loading: "lazy" }));
  info.append(icons);
  sum.append(info);
  card.append(sum);
  const list = el("div", { class: "skills" });
  for (const s of h.skills) {
    const row = el("div", { class: "skill" });
    row.append(el("img", { src: "img/skills/" + s.icon + ".webp", alt: "", loading: "lazy" }));
    const body = el("div");
    const head = el("div", { class: "name" });
    head.append(el("span", { class: "slot" }, s.slot), document.createTextNode(s.name));
    body.append(head, el("p", {}, s.text));
    row.append(body);
    list.append(row);
  }
  card.append(list);
  return card;
}

async function showHeroes() {
  const box = document.querySelector("[data-heroes]");
  try {
    const res = await fetch("heroes.json", { cache: "no-cache" });
    const heroes = await res.json();
    for (const h of heroes) box.append(heroCard(h));
  } catch (e) {
    box.append(el("p", { class: "muted" }, "Chưa tải được danh sách tướng."));
  }
}

showVersion();
showHeroes();
