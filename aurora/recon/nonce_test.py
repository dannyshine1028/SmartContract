import json, subprocess, urllib.request, urllib.error, http.cookiejar, time
BASE="https://aurora.plus"; UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/124 Safari/537.36"
A0="0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"; PK0="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
A1="0x70997970C51812dc3A010C7d01b50e0d17dc79C8"
def sign(msg,pk): return subprocess.run(["cast","wallet","sign","--private-key",pk,msg],capture_output=True,text=True).stdout.strip()
def msg(n): return f"Welcome to Aurora+\n\nClick to authenticate and accept our Terms of Service (https://aurora.plus/terms).\n\nNonce: {n}"
def req(m,p,d=None,jar=None):
    op=urllib.request.build_opener(urllib.request.HTTPCookieProcessor(jar if jar is not None else http.cookiejar.CookieJar()))
    h={"User-Agent":UA,"Accept":"application/json, */*","Origin":BASE,"Referer":BASE+"/"}
    b=None
    if d is not None: b=json.dumps(d).encode(); h["Content-Type"]="application/json"
    r=urllib.request.Request(BASE+p,data=b,headers=h,method=m)
    try:
        with op.open(r,timeout=25) as x: return x.status,dict(x.headers),x.read(600)
    except urllib.error.HTTPError as e: return e.code,dict(e.headers),e.read(600)
    except Exception as e: return -1,{},repr(e).encode()
# nonces
n0=json.loads(req("GET",f"/api/accounts/get-nonce?address={A0}")[2])["nonce"]
n1=json.loads(req("GET",f"/api/accounts/get-nonce?address={A1}")[2])["nonce"]
print("nonce0",n0,"nonce1",n1)
tests=[
 ("sig(A0)+addr A1 with nonce1", A1, sign(msg(n1),PK0), "sig from A0 key, body address A1"),
 ("sig(A0)+addr A1 with nonce0", A1, sign(msg(n0),PK0), "sig from A0 key/nonce0, body address A1"),
 ("sig(A0) wrong nonce 000000 addr A0", A0, sign(msg("000000"),PK0), "wrong nonce self"),
 ("sig(A0) nonce0 addr A0 (valid)", A0, sign(msg(n0),PK0), "valid self"),
 ("replay same sig addr A0", A0, sign(msg(n0),PK0), "replay after success"),
]
for name,addr,sig,desc in tests:
    jar=http.cookiejar.CookieJar()
    st,hd,b=req("POST","/api/accounts/authenticate",{"address":addr,"signedMessage":sig,"termsReadTimestamp":str(int(time.time()*1000))},jar=jar)
    cookies=[c.name for c in jar]
    print(f"### {name}\n  {st} {b!r} cookies={cookies}")
