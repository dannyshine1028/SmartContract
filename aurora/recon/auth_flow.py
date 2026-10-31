import json, subprocess, urllib.request, urllib.error, http.cookiejar, time, re, sys

BASE="https://aurora.plus"
UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Safari/537.36"
W=json.load(open('/tmp/aurora_wallet/wallet.json'))['data'][0]
ADDR=W['address']; PK=W['private_key']

cj=http.cookiejar.CookieJar()
opener=urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cj))

def req(method, path, data=None, headers=None, timeout=25):
    h={"User-Agent":UA,"Accept":"application/json, text/plain, */*","Origin":BASE,"Referer":BASE+"/"}
    if headers: h.update(headers)
    body=None
    if data is not None:
        body=json.dumps(data).encode(); h["Content-Type"]="application/json"
    r=urllib.request.Request(BASE+path, data=body, headers=h, method=method)
    try:
        with opener.open(r, timeout=timeout) as resp:
            return resp.status, dict(resp.headers), resp.read(3000)
    except urllib.error.HTTPError as e:
        return e.code, dict(e.headers), e.read(3000)
    except Exception as e:
        return -1, {}, repr(e).encode()

def cookies():
    return [(c.name, c.value, c.domain, c.path) for c in cj]

# 1. nonce
st,hd,body=req("GET", f"/api/accounts/get-nonce?address={ADDR}")
print("nonce:", st, body)
nonce=json.loads(body)["nonce"]
msg=f"Welcome to Aurora+\n\nClick to authenticate and accept our Terms of Service (https://aurora.plus/terms).\n\nNonce: {nonce}"
sig=subprocess.run(["cast","wallet","sign","--private-key",PK,msg],capture_output=True,text=True).stdout.strip()
print("sig:", sig[:20]+"...", "len", len(sig))
# 2. authenticate
st,hd,body=req("POST","/api/accounts/authenticate",{"address":ADDR,"signedMessage":sig,"termsReadTimestamp":str(int(time.time()*1000))})
print("authenticate:", st, body)
print("  headers:", {k:v for k,v in hd.items() if k.lower() in ('set-cookie','content-type','access-control-allow-origin','access-control-allow-credentials')})
print("  cookies:", cookies())
# 3. checkSession
st,hd,body=req("POST","/api/accounts/checkSession",{"address":ADDR})
print("checkSession:", st, body, "cookies:", cookies())
# 4. account info own vs other
for a in [ADDR, "0x0000000000000000000000000000000000000001", "0x0000000000000000000000000000000000000000"]:
    st,hd,body=req("GET", f"/api/accounts/{a}", headers={"Origin":"https://evil.example"})
    print(f"account {a}:", st, body[:600])
    print("   cors:", {k:v for k,v in hd.items() if k.lower().startswith('access-control')})
