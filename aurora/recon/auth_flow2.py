import json, subprocess, urllib.request, urllib.error, http.cookiejar, time, sys

BASE="https://aurora.plus"
UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Safari/537.36"
ADDR="0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
PK="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"

cj=http.cookiejar.CookieJar()
opener=urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cj))

def req(method, path, data=None, headers=None, timeout=25, use_opener=True):
    h={"User-Agent":UA,"Accept":"application/json, text/plain, */*","Origin":BASE,"Referer":BASE+"/"}
    if headers: h.update(headers)
    body=None
    if data is not None:
        body=json.dumps(data).encode(); h["Content-Type"]="application/json"
    r=urllib.request.Request(BASE+path, data=body, headers=h, method=method)
    op=opener if use_opener else urllib.request.build_opener()
    try:
        with op.open(r, timeout=timeout) as resp:
            return resp.status, dict(resp.headers), resp.read(4000)
    except urllib.error.HTTPError as e:
        return e.code, dict(e.headers), e.read(4000)
    except Exception as e:
        return -1, {}, repr(e).encode()

def ck(): return [(c.name, c.value) for c in cj]

st,hd,body=req("GET", f"/api/accounts/get-nonce?address={ADDR}")
print("nonce:",st,body); nonce=json.loads(body)["nonce"]
msg=f"Welcome to Aurora+\n\nClick to authenticate and accept our Terms of Service (https://aurora.plus/terms).\n\nNonce: {nonce}"
sig=subprocess.run(["cast","wallet","sign","--private-key",PK,msg],capture_output=True,text=True).stdout.strip()
print("sig:",sig[:24],len(sig))
st,hd,body=req("POST","/api/accounts/authenticate",{"address":ADDR,"signedMessage":sig,"termsReadTimestamp":str(int(time.time()*1000))})
print("authenticate:",st,body)
print(" cookies:",ck())
print(" setcookie:",hd.get("set-cookie"))
st,hd,body=req("POST","/api/accounts/checkSession",{"address":ADDR})
print("checkSession:",st,body)
for a,label in [(ADDR,"self"),("0x0000000000000000000000000000000000000001","other1"),("0xc456fd17e9342dff2340b1e98e5f5e6b6188b750","other2")]:
    st,hd,body=req("GET", f"/api/accounts/{a}")
    print(f"account[{label}] {a}:",st,body[:1200])
