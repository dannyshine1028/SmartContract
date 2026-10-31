import json, subprocess, urllib.request, urllib.error, http.cookiejar, time
BASE="https://aurora.plus"; UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/124 Safari/537.36"
ADDR="0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"; PK="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
cj=http.cookiejar.CookieJar(); op=urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cj))
def req(m,p,d=None,to=25):
    h={"User-Agent":UA,"Accept":"application/json, */*","Origin":BASE,"Referer":BASE+"/"}
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
print("cookies:",[(c.name,c.value[:12]+"..") for c in cj])
tests=[
 ("GET","/api/accounts/0x70997970C51812dc3A010C7d01b50e0d17dc79C8",None),
 ("GET","/api/accounts/0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC",None),
 ("GET","/api/accounts/0x90F79bf6EB2c4f870365E785982E1f101E93b906",None),
 ("GET","/api/accounts/0x1111111111111111111111111111111111111111",None),
 ("POST","/api/accounts/checkSession",{"address":"0x70997970C51812dc3A010C7d01b50e0d17dc79C8"}),
 ("GET","/api/forwarder/tokens?siloId=0",None),
 ("GET","/api/forwarder/tokens?siloId=1",None),
 ("GET","/api/forwarder/status?address=0x70997970C51812dc3A010C7d01b50e0d17dc79C8&siloId=0",None),
 ("GET","/api/forwarder/status?address=0x70997970C51812dc3A010C7d01b50e0d17dc79C8&siloId=1",None),
 ("GET","/api/forwarder/history?proxyAddress=0x70997970C51812dc3A010C7d01b50e0d17dc79C8&userAddress=0x70997970C51812dc3A010C7d01b50e0d17dc79C8",None),
 ("GET","/api/forwarder/history?proxyAddress=0x70997970C51812dc3A010C7d01b50e0d17dc79C8&userAddress=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",None),
 ("GET","/api/campaigns",None),
]
for m,p,d in tests:
    st,hd,b=req(m,p,d)
    print(f"### {m} {p}\n  {st} {b[:800]!r}")
