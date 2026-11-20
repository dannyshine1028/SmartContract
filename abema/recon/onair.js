(function(){
  var setPoster = function(channel){
    var url = 'https://image.p-c2-x.abema-tv.com/media/channels/time'
    var dt = (function(d){return [
                    d.getFullYear(),
                    ('0' + (d.getMonth() + 1)).slice(-2),
                    ('0' + d.getDate()).slice(-2),
                    ('0' + d.getHours()).slice(-2),
                    ('0' + d.getMinutes()).slice(-2),
                    ('0' + d.getSeconds()).slice(-2).substring(0, 1) + '0'
                    ].join('')})(new Date());
    var poster = url + '/' + dt + '/' + channel + '.webp?format=jpg&width=424';
    Array.prototype.forEach.call(document.querySelectorAll('.js-onair-poster'), function(image){image.src=poster;});
  }

  //if ($('.js-onair-fix').length === 0) return;
  
  var channel = ''
  setPoster(channel);

  var infoUrl = "https://api.abema.io/v1/broadcast/slots?division=0";
  var req = new XMLHttpRequest();
  req.onload = function(event) {
    if ((event.target.readyState==4) && (event.target.status=='200')) {
      var slots = JSON.parse(this.responseText).slots;
      var targetSlot = slots.find(function(slot){ return (slot.channelId === channel);});
      if (!targetSlot && channel == 'sumo') {
        channel = 'world-sports'
        setPoster(channel);
        Array.prototype.forEach.call(document.querySelectorAll('.js-onair-logo'), function(image){image.src=image.src.replaceAll('sumo', channel);});
        targetSlot = slots.find(function(slot){ return (slot.channelId === channel);});
      }
      var startTime = new Date(parseInt(targetSlot.startAt,10) * 1000);
      var endTime = new Date(parseInt(targetSlot.endAt,10) * 1000);
      var from = '〜'+endTime.toLocaleTimeString().split(':').slice(0,2).join(':') + ' <span>放送中</span>';
      console.log(from);
      var lead = ' '+targetSlot.title;
      Array.prototype.forEach.call(document.querySelectorAll('.js-onair-from'), function(node){node.innerHTML = from;});
      Array.prototype.forEach.call(document.querySelectorAll('.js-onair-lead'), function(node){node.textContent = lead;});
    }
  };
  req.open('GET', infoUrl, true);
  req.send();
/*
  document.querySelector('.js-onair-close').addEventListener('click', function() {
    document.querySelector('.js-onair-fix').style.display = 'none';
  });
*/
})();
