import json,re,http.cookiejar,urllib.request,urllib.parse,os,html
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36"
CK="cookies_test.txt"
class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self,req,fp,code,msg,headers,newurl): return None
def load():
    cj=http.cookiejar.MozillaCookieJar(CK)
    if os.path.exists(CK):
        try: cj.load(ignore_discard=True,ignore_expires=True)
        except Exception as e: print("cookieload",e)
    return cj
def save(cj): cj.save(ignore_discard=True,ignore_expires=True)
def opener(cj,follow=True):
    hs=[urllib.request.HTTPCookieProcessor(cj)]
    if not follow: hs.append(NoRedirect())
    op=urllib.request.build_opener(*hs); op.addheaders=[("User-Agent",UA),("Accept-Language","en")]; op.cj=cj
    return op
def req(op,url,data=None,headers=None,raw=None,method=None):
    d=raw if raw is not None else (urllib.parse.urlencode(data).encode() if isinstance(data,dict) else data)
    r=urllib.request.Request(url,data=d,method=method or ("POST" if d else "GET"))
    for k,v in (headers or {}).items(): r.add_header(k,v)
    try:
        resp=op.open(r,timeout=40); return resp.status,(resp.geturl()),resp.read().decode('utf8','replace'),dict(resp.headers)
    except urllib.error.HTTPError as e:
        return e.code,url,e.read().decode('utf8','replace'),dict(e.headers or {})
def tok(op,url):
    st,u,b,h=req(op,url); m=re.search(r'name="csrfmiddlewaretoken" value="([^"]+)"',b)
    return (m.group(1) if m else None),b
def text(b):
    b=re.sub(r'<(script|style)[^>]*>.*?</\1>','',b,flags=re.S|re.I)
    return re.sub(r'\s+',' ',html.unescape(re.sub(r'<[^>]+>',' ',b))).strip()
def links(b,base="https://xeovo.com"):
    out=[]
    for h in re.findall(r'(?:href|action|src)="([^"]+)"',b):
        h=html.unescape(h)
        if h.startswith("/"): out.append(base+h)
        elif h.startswith("http") and "xeovo" in h: out.append(h)
    return sorted(set(out))
def login(uname,pw):
    cj=load(); op=opener(cj)
    t,page=tok(op,"https://xeovo.com/login/")
    st,u,b,h=req(op,"https://xeovo.com/login/",{"csrfmiddlewaretoken":t,"username":uname,"password":pw,"next":"/dashboard/"},
                 {"Referer":"https://xeovo.com/login/","Origin":"https://xeovo.com"})
    ok="Dashboard" in b and "Log In -" not in b[:200]
    save(cj)
    return op,cj,ok,u,len(b)
