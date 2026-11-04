
function initSly() {

  $('.slidee > *').each(function() {
    // var width = $(this).width() + 20;
    var width = $(this).data('slidee-width') ? $(this).data('slidee-width') : $(this).width();
    width += 20;

    var childrenLength = $(this).parent('.slidee').children().length;
    if($(this).index() == childrenLength - 1){
      width += 40;
    }

    $(this).css('width', width + 'px');
    // console.log($(this).html(), width);
  });

  var slyOptions = {
    // slidee: '.slidee',
    horizontal: 1,
    itemNav: 'basic',
    smart: 1,
    activateOn: 'click',
    mouseDragging: 1,
    touchDragging: 1,
    releaseSwing: 1,
    speed: 300,
    elasticBounds: 1,
    startAt: 0,
    itemSelector: 'div',
  };

  var slyOptions2 = {
    slidee: '.slidee',
    speed: 300,
	  smart: 1,
    prev: '.dashboard__slider-prev',
    next: '.dashboard__slider-next',
  };

  $('#features__menu--frame').sly(slyOptions);
  $('#about__menu--frame').sly(slyOptions);
  $('#guides__systems--frame').sly(slyOptions);
  $('#dashboard__slider--frame').sly(slyOptions2);
}

function initTabs() {
  $('.tabs a:not(.active)').each(function(index) {

    var tabId = $(this).attr('href');

    if ($(this).parents('.mobile-disable').length > 0 && $(window).width() <= 960) {
      $(tabId).css('display', '');
      return;
    }

    $(tabId).css('display', 'none');
  });
}

function disableSly(argument) {
  $('#features__menu--frame').sly(false);
  $('#about__menu--frame').sly(false);
  $('#guides__systems--frame').sly(false);

  $('.slidee > *').each(function() {
    $(this).css('width', '');
  });
}

function handleWindowSize() {
  if($(window).width() <= 960){
    initSly();
  }
  else {
    disableSly();
  }
}

$(window).resize(function() {
  initTabs();
  handleWindowSize();
});

initTabs();

$(document).ready(function() {

  handleWindowSize();
  
  $('.sidebar__menu__block span').click(function() {
    $('.sidebar__menu__block.active').removeClass('active');
    $(this).parents('.sidebar__menu__block').first().addClass('active');
  });

  

  $('.tabs a').click(function(e) {
    e.preventDefault();
    if($(this).hasClass('active')){
      return;
    }

    var activeLink = $(this).parents('.tabs').find('a.active');
    activeLink.removeClass('active');
    var activeTabId = activeLink.attr('href');
    $(activeTabId).css('display', 'none');

    var newTabId = $(this).attr('href');
    $(newTabId).removeAttr('style');

    $(this).addClass('active');
  });
  

});
