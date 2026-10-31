import json, subprocess, urllib.request, urllib.error, http.cookiejar, time
BASE="https://aurora.plus"; UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/124 Safari/537.36"
ADDR="0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"; PK="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
OTHER="0x70997970C51812dc3A010C7d01b50e0d17dc79C8"
cj=http.cookiejar.CookieJar(); op=urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cj))
def req(m,p,d=None,to=30):
    h={"User-Agent":UA,"Accept":"application/json, */*","Origin":BASE,"Referer":BASE+"/forwarder"}
    b=None
    if d is not None: b=json.dumps(d).encode(); h["Content-Type"]="application/json"
    r=urllib.request.Request(BASE+p,data=b,headers=h,method=m)
    try:
        with op.open(r,timeout=to) as x: return x.status,dict(x.headers),x.read(4000)
    except urllib.error.HTTPError as e: return e.code,dict(e.headers),e.read(4000)
    except Exception as e: return -1,{},repr(e).encode()
st,_,b=req("GET",f"/api/accounts/get-nonce?address={ADDR}"); nonce=json.loads(b)["nonce"]
msg=f"Welcome to Aurora+\n\nClick to authenticate and accept our Terms of Service (https://aurora.plus/terms).\n\nNonce: {nonce}"
sig=subprocess.run(["cast","wallet","sign","--private-key",PK,msg],capture_output=True,text=True).stdout.strip()
st,_,b=req("POST","/api/accounts/authenticate",{"address":ADDR,"signedMessage":sig,"termsReadTimestamp":str(int(time.time()*1000))})
print("auth:",st,b)
T=[("GET","/api/forwarder/tokens?siloId=aurora",None),
   ("GET",f"/api/forwarder/status?address={ADDR}&siloId=aurora",None),
   ("GET",f"/api/forwarder/status?address={OTHER}&siloId=aurora",None),
   ("GET",f"/api/forwarder/status?address=0xc456fd17e9342dff2340b1e98e5f5e6b6188b750&siloId=aurora",None),
   ("GET",f"/api/forwarder/history?proxyAddress={ADDR}&userAddress={ADDR}",None),
   ("GET",f"/api/forwarder/history?proxyAddress=0x0000000000000000000000000000000000000001&userAddress={ADDR}",None),
   ("POST","/api/accounts/checkSession",{"address":OTHER}),
   ("GET",f"/api/accounts/{OTHER}",None)]
for m,p,d in T:
    st,hd,b=req(m,p,d)
    print(f"### {m} {p}\n  {st} {b[:700]!r}")
