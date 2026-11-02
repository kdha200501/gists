#!/usr/bin/env node
const ACCOUNT_ID = "5324042807001";
const PLAYER_KEY = "t3oBfbU6IW_default";
const ORIGIN = "https://tvbanywherena.com";

async function main() {
  const arg = process.argv[2];
  if (!arg) {
    console.error("usage: node build-m3u8.js <watch-page-url | videoId>");
    process.exit(1);
  }
  const m = arg.match(/\/(\d{10,})(?:\?|$)/);
  const videoId = m ? m[1] : arg;
  if (!/^\d+$/.test(videoId)) {
    console.error("could not extract video id from: " + arg);
    process.exit(1);
  }

  const cfgRes = await fetch(`https://players.brightcove.net/${ACCOUNT_ID}/${PLAYER_KEY}/config.json`);
  if (!cfgRes.ok) throw new Error(`player config ${cfgRes.status}`);
  const cfg = await cfgRes.json();
  const policyKey = cfg.video_cloud?.policy_key || cfg.policy_key;
  if (!policyKey) throw new Error("policy_key not found in player config: " + JSON.stringify(Object.keys(cfg)));

  const res = await fetch(
    `https://edge.api.brightcove.com/playback/v1/accounts/${ACCOUNT_ID}/videos/${videoId}`,
    { headers: { "BCOV-Policy": policyKey, Origin: ORIGIN, Referer: ORIGIN + "/" } },
  );
  if (!res.ok) throw new Error(`playback API ${res.status}: ${(await res.text()).slice(0, 300)}`);
  const data = await res.json();

  const hls = (data.sources || []).filter((s) => s.type === "application/x-mpegURL" && s.src.startsWith("https://"));
  if (!hls.length) {
    console.error("no https HLS source. types: " + JSON.stringify((data.sources || []).map((s) => s.type)));
    process.exit(1);
  }
  console.log(hls[0].src);
}

main().catch((e) => {
  console.error(e.message);
  process.exit(1);
});
