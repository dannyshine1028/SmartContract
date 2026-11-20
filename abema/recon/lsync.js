var MiU=MiU||{};MiU.queue=MiU.queue||[];
MiU.data = MiU.data||{};
MiU.fire = function(siteData) {
 if (((typeof siteData)=='object') && ('media' in siteData)) {MiU.data = siteData;}
 (function() {
  var protocol = document.referrer.substr(0, (document.referrer.indexOf('://') + 3));
  var refer = document.referrer.substr(protocol.length, document.referrer.length);
  var refers = refer.split('/');
  var referHost = refers[0];
  var defaultData = {
    'host' : document.location.hostname,
    'path' : document.location.pathname,
    'rhost' : referHost,
    'rpath' : refer.substr(referHost.length, refer.length),
  }
  if (!(document.location.search.substr(1) == null || document.location.search.substr(1) == '')){defaultData.query = document.location.search.substr(1);}
  var query = '';
  for(var key in MiU.data){query += key + '=' + encodeURIComponent(MiU.data[key]) + '&';}
  for(var key in defaultData){query += key + '=' + encodeURIComponent(defaultData[key]) + '&';}
  var img = new Image();
  query += 'rd=' + Math.random();
  img.src = '/oo/life/m.gif?' + query;
 })();
};
MiU.go = function(){try{var current=null;while(current=MiU.queue.shift()){try {current();}catch(err){}}}catch(err){}};
MiU.queue.push=function(){Array.prototype.push.apply(this,arguments);setTimeout(MiU.go,1);return this.length;};
setTimeout(MiU.go,20);
