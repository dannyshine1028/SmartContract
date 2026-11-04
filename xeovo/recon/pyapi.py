import re,sys,urllib.request,urllib.parse,http.cookiejar,json
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36"
def jar(f):
    cj=http.cookiejar.MozillaCookieJar(f)
    try: cj.load(ignore_discard=True,ignore_expires=True)
    except Exception as e: pass
    return cj
def op(f,follow=True):
    cj=jar(f)
    class NR(urllib.request.HTTPRedirectHandler):
        def redirect_request(self,req,fp,code,msg,headers,newurl): return None
    hs=[urllib.request.HTTPCookieProcessor(cj)]
    if not follow: hs.append(NR())
    o=urllib.request.build_opener(*hs); o.addheaders=[("User-Agent",UA)]; o.cj=cj
    return o
import time
def go(o,url,data=None,headers=None,method=None,retry=4):
    last=None
    for i in range(retry):
        d=urllib.parse.urlencode(data).encode() if isinstance(data,dict) else data
        r=urllib.request.Request(url,data=d,method=method or ("POST" if d is not None else "GET"))
        for k,v in (headers or {}).items(): r.add_header(k,v)
        try:
            resp=o.open(r,timeout=40)
            return resp.status,resp.geturl(),resp.read().decode('utf8','replace'),dict(resp.headers)
        except urllib.error.HTTPError as e:
            if e.code in (403,429,503) and i<retry-1: time.sleep(1.5); continue
            return e.code,url,e.read().decode('utf8','replace'),dict(e.headers or {})
        except Exception as e:
            last=e; time.sleep(2.0); continue
    return 0,url,"FETCHFAIL "+str(last),{}
def login(u,p,f):
    import os
    if os.path.exists(f): os.remove(f)
    o=op(f)
    t=go(o,"https://xeovo.com/login/")[2]
    tok=re.search(r'name="csrfmiddlewaretoken" value="([^"]+)"',t).group(1)
    st,fin,b,h=go(o,"https://xeovo.com/login/",{"csrfmiddlewaretoken":tok,"username":u,"password":p,"next":"/dashboard/"},
                  {"Referer":"https://xeovo.com/login/","Origin":"https://xeovo.com"})
    o.cj.save(f,ignore_discard=True,ignore_expires=True)
    return st,fin,("Dashboard" in b)
def meta(o,url):
    b=go(o,url)[2]
    return (re.search(r'name="x-csrf-token" content="([^"]+)"',b) or [None,None])[1] if re.search(r'name="x-csrf-token" content="([^"]+)"',b) else None
