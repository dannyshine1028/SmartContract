import json, subprocess, urllib.request, urllib.error, http.cookiejar, time
BASE="https://aurora.plus"; UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/124 Safari/537.36"
A0="0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"; PK0="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
MIS="0x000000000000000000000000000000000000dEaD"
jar=http.cookiejar.CookieJar()
def call(m,p,d=None):
    op=urllib.request.build_opener(urllib.request.HTTPCookieProcessor(jar))
    h={"User-Agent":UA,"Accept":"application/json, */*","Origin":BASE,"Referer":BASE+"/"}
    b=None
    if d is not None: b=json.dumps(d).encode(); h["Content-Type"]="application/json"
    r=urllib.request.Request(BASE+p,data=b,headers=h,method=m)
    try:
        with op.open(r,timeout=25) as x: return x.status,x.read(1000)
    except urllib.error.HTTPError as e: return e.code,e.read(1000)
    except Exception as e: return -1,repr(e).encode()
def login():
    for _ in range(3):
        st,b=call("GET",f"/api/accounts/get-nonce?address={A0}")
        if st==200: break
        time.sleep(2)
    nonce=json.loads(b)["nonce"]
    m=f"Welcome to Aurora+\n\nClick to authenticate and accept our Terms of Service (https://aurora.plus/terms).\n\nNonce: {nonce}"
    sig=subprocess.run(["cast","wallet","sign","--private-key",PK0,m],capture_output=True,text=True).stdout.strip()
    return call("POST","/api/accounts/authenticate",{"address":A0,"signedMessage":sig,"termsReadTimestamp":str(int(time.time()*1000))})
print("login",login())
T=[("POST","/api/accounts/set-has-staked",{"address":A0}),
   ("POST","/api/accounts/set-has-staked",{"address":MIS}),
   ("POST","/api/accounts/add-to-swapping-whitelist",{"address":A0}),
   ("POST","/api/accounts/add-to-swapping-whitelist",{"address":MIS}),
   ("POST","/api/accounts/save-not-us-citizen-signature",{"address":MIS,"signature":"0x"+"00"*65}),
   ("POST","/api/accounts/checkSession",{"address":MIS}),
   ("POST","/api/campaigns/create-segment",{"campaignId":"probe-nonexistent","name":"probe","segments":[]}),
   ("POST","/api/campaigns/delete-segment",{"campaignId":"probe-nonexistent","segmentId":"probe-nonexistent"}),
   ("POST","/api/campaigns/redeem-code",{"code":"probe-invalid-code-zz","addressForAirdrop":MIS}),
  ]
for m,p,d in T:
    for attempt in range(2):
        st,b=call(m,p,d)
        if st!=-1: break
        time.sleep(2)
    print(f"### {m} {p} {json.dumps(d)[:90]}\n  {st} {b[:400]!r}")
