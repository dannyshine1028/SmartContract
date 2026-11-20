const fs = require("fs");
const s = fs.readFileSync("/home/user/Documents/Work/Guk/3.BugBounty/Source/abema/recon/cc_xhrp-XK6ZFGMO.js", "utf8");
const m = s.match(/\["([^\]]*?)"\]|\['([^\]]*?)'\]/);
const raw = m[0];
const arr = raw.slice(2, -2).split(m[1] !== undefined ? '","' : "','");
console.log("array size", arr.length);
console.log(arr.join("\n"));
