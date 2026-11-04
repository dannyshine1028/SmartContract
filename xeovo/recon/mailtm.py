import json,urllib.request,urllib.error
def api(p,tok,data=None):
    d=json.dumps(data).encode() if data else None
    r=urllib.request.Request("https://api.mail.tm"+p,data=d,method="POST" if d else "GET",
        headers={"Authorization":"Bearer "+tok,"Content-Type":"application/json"})
    try: return json.loads(urllib.request.urlopen(r,timeout=25).read().decode())
    except urllib.error.HTTPError as e: return {"err":e.code}
def msgs(tok):
    m=api("/messages?page=1",tok)
    out=[]
    for x in m.get("hydra:member",[]):
        f=api("/messages/"+x["id"],tok); f["mid"]=x["id"]; out.append(f)
    return out
def links(tok):
    import re
    return [(f["subject"],re.findall(r'https?://[^\s"\'<>]+',f.get("text",""))) for f in msgs(tok)]
