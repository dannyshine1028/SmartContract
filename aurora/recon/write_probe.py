import json, urllib.request, urllib.error
BASE="https://aurora.plus"; UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/124 Safari/537.36"
def req(m,p,d=None,origin=BASE):
    h={"User-Agent":UA,"Accept":"application/json, text/plain, */*","Origin":origin,"Referer":BASE+"/"}
    b=None
    if d is not None:
        b=json.dumps(d).encode(); h["Content-Type"]="application/json"
    r=urllib.request.Request(BASE+p,data=b,headers=h,method=m)
    try:
        with urllib.request.urlopen(r,timeout=25) as x: return x.status,dict(x.headers),x.read(800)
    except urllib.error.HTTPError as e: return e.code,dict(e.headers),e.read(800)
    except Exception as e: return -1,{},repr(e).encode()
T=[("POST","/api/accounts/save-not-us-citizen-signature",{"address":"0x0000000000000000000000000000000000000001","signature":"0x"+"00"*65}),
   ("POST","/api/campaigns/redeem-code",{"code":"zzzz-invalid-test-code-0000","addressForAirdrop":"0x0000000000000000000000000000000000000001"}),
   ("POST","/api/transak/save-transaction",{"eventName":"TEST_PROBE","data":{"x":1}}),
   ("GET","/api/market/chart?coin=aurora-near&period=1d",None),
   ("GET","/api/munzen/signature?toWallet=0x0000000000000000000000000000000000000001&toCurrency=usdt-AURORA&externalData=%7B%22silo%22%3A%221%22%7D",None),
   ("GET","/api/munzen/signature?toWallet=0x0000000000000000000000000000000000000002&toCurrency=usdt-AURORA&externalData=%7B%22silo%22%3A%221%22%7D",None),
   ("GET","/api/munzen/signature?toWallet=0xc456fd17e9342dff2340b1e98e5f5e6b6188b750&toCurrency=usdc-AURORA&externalData=%7B%22silo%22%3A%222%22%7D",None)]
for m,p,d in T:
    st,hd,body=req(m,p,d)
    print(f"### {m} {p}\n  {st} {hd.get('content-type')}\n  {body[:500]!r}")
