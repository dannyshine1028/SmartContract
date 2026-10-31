import json, subprocess, urllib.request, urllib.error, http.cookiejar, time
BASE="https://aurora.plus"; UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/124 Safari/537.36"
ACCTS={
 "a0":("0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266","0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"),
 "a1":("0x70997970C51812dc3A010C7d01b50e0d17dc79C8","0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d"),
 "a2":("0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC","0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a"),
}
def sign(msg,pk): return subprocess.run(["cast","wallet","sign","--private-key",pk,msg],capture_output=True,text=True).stdout.strip()
def msg(n): return f"Welcome to Aurora+\n\nClick to authenticate and accept our Terms of Service (https://aurora.plus/terms).\n\nNonce: {n}"
def call(jar,m,p,d=None):
    op=urllib.request.build_opener(urllib.request.HTTPCookieProcessor(jar))
    h={"User-Agent":UA,"Accept":"application/json, */*","Origin":BASE,"Referer":BASE+"/"}
    b=None
    if d is not None: b=json.dumps(d).encode(); h["Content-Type"]="application/json"
    r=urllib.request.Request(BASE+p,data=b,headers=h,method=m)
    try:
        with op.open(r,timeout=25) as x: return x.status,x.read(2000)
    except urllib.error.HTTPError as e: return e.code,e.read(2000)
    except Exception as e: return -1,repr(e).encode()
def login(key):
    addr,pk=ACCTS[key]; jar=http.cookiejar.CookieJar()
    st,b=call(jar,"GET",f"/api/accounts/get-nonce?address={addr}")
    if st!=200: return None,("nonce",st,b)
    nonce=json.loads(b)["nonce"]
    st,b=call(jar,"POST","/api/accounts/authenticate",{"address":addr,"signedMessage":sign(msg(nonce),pk),"termsReadTimestamp":str(int(time.time()*1000))})
    if st!=200: return None,("auth",st,b)
    return jar,("ok",addr)

def prof(key):
    jar,info=login(key)
    if jar is None: return info
    addr=ACCTS[key][0]
    st,b=call(jar,"GET",f"/api/accounts/{addr}")
    return st,b

print("profile a1:",prof("a1"))
print("profile a2:",prof("a2"))
# campaign read authz with a0 session
jar0,_=login("a0")
for p in ["/api/campaigns/1","/api/campaigns/test","/api/campaigns/create-segment"]:
    st,b=call(jar0,"GET",p); print("GET",p,st,b[:300])
for p,d in [("/api/campaigns/create-segment",{"campaignId":"nonexistent-probe","name":"probe","segments":[]}),
            ("/api/campaigns/delete-segment",{"campaignId":"nonexistent-probe","segmentId":"nonexistent-probe"})]:
    st,b=call(jar0,"POST",p,d); print("POST",p,st,b[:300])
