#!/usr/bin/env node
// Parse a TVB Anywhere page (watch/episode page OR series/show page) and
// emit a compact JSON description on stdout.
//
// usage: node parse-page.js <path-to-saved-html>
//
// episode page -> { type: "episode", showName, episodeNo, episodeName, videoId, url }
// show page    -> { type: "show", showName, episodes: [{ no, name, url }] }
//
// exit 1 with a reason on stderr when the page can't be classified.

const fs = require("fs");

const html = fs.readFileSync(process.argv[2], "utf8");

function twoDigit(n) {
  const x = parseInt(n, 10);
  return Number.isFinite(x) ? String(x).padStart(2, "0") : "00";
}

function episodeNoFrom(name, index) {
  if (name) {
    const m = String(name).match(/(\d+)/);
    if (m) return twoDigit(m[1]);
  }
  return twoDigit((index || 0) + 1);
}

function showNameFromOgTitle() {
  const m = /og:title" content="([^"]+)"/.exec(html);
  if (!m) return null;
  return m[1].split(/\s+—\s+/)[0].trim() || null;
}

function jsonLdBlocks() {
  const out = [];
  const re = /<script[^>]*type="application\/ld\+json"[^>]*>([\s\S]*?)<\/script>/g;
  let m;
  while ((m = re.exec(html))) {
    try { out.push(JSON.parse(m[1])); } catch (e) { /* keep going */ }
  }
  return out;
}

function videoIdFromUrl(url) {
  const m = /\/(\d{15,})(?:\?|$)/.exec(url || "");
  return m ? m[1] : null;
}

// --- Show page: TVSeries with containsSeason[].episode[] ---
for (const obj of jsonLdBlocks()) {
  const seasons = obj && obj.containsSeason ? [].concat(obj.containsSeason) : [];
  if (obj && obj["@type"] === "TVSeries" && seasons.length && seasons[0].episode) {
    const eps = seasons.flatMap((s) => [].concat(s.episode || [])).map((e, i) => ({
      no: episodeNoFrom(e.name, i),
      name: e.name || `Episode ${i + 1}`,
      url: e.url || "",
    }));
    if (eps.length) {
      console.log(JSON.stringify({ type: "show", showName: obj.name || null, episodes: eps }, null, 2));
      process.exit(0);
    }
  }
}

// --- Episode page: VideoObject / TVEpisode ---
for (const obj of jsonLdBlocks()) {
  const t = obj && obj["@type"];
  if (t === "VideoObject" || t === "TVEpisode") {
    const name = obj.name || "";
    const url = obj.url || "";
    const og = showNameFromOgTitle();
    const m = name.match(/(\d+)/);
    let showName = og;
    if (!showName) {
      // og:title looked like "Show — 第08集"; fall back to stripping the 第NN集 from the title
      const t2 = /og:title" content="([^"]+)"/.exec(html);
      const base = t2 ? t2[1] : "";
      showName = base.replace(/第\d+集.*$/u, "").replace(/[-—–\s]*$/, "").trim() || "Show";
    }
    console.log(JSON.stringify({
      type: "episode",
      showName,
      episodeNo: m ? twoDigit(m[1]) : "01",
      episodeName: name,
      videoId: videoIdFromUrl(url),
      url,
    }, null, 2));
    process.exit(0);
  }
}

console.error("could not classify page as a show or an episode (no TVSeries/VideoObject JSON-LD found)");
process.exit(1);
