const fs = require("fs");
const P = "/home/user/Documents/Work/Guk/3.BugBounty/Source/abema/recon/cc_xhrp-XK6ZFGMO.js";
const s = fs.readFileSync(P, "utf8");
// collect every string array literal in the file
const arrays = [...s.matchAll(/\[((?:'[^']*'|"[^"]*")(?:,(?:'[^']*'|"[^"]*"))+)\]/g)];
console.log("arrays found:", arrays.length);
const all = [];
for (const a of arrays) {
  const parts = a[1].match(/'([^']*)'|"([^"]*)"/g).map(x => x.slice(1, -1));
  all.push(...parts);
}
const uniq = [...new Set(all)];
console.log("unique strings:", uniq.length);
const keyish = uniq.filter(x => /^[0-9a-fA-F]{16,64}$/.test(x) || x.length === 16 || x.length === 32);
console.log("key/iv-like literals:", keyish.slice(0, 40));
console.log("--- all non-boilerplate strings ---");
console.log(uniq.filter(x => x.length > 3 && !/^[0-9]+[A-Za-z]{6,}$/.test(x)).join("\n"));
