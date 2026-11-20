$(function () {
  var TOOLS = TOOLS || {};

  TOOLS = {
    init: function () {
      this.addNoopener();
      this.lazyLoad();
      this.luminousGallery();
      this.smoothScroll();
      this.switchRanking();
      this.headerNav();
      this.search();
      this.switchMiniCalendarTab();
      this.language();
      this.previousLink();
      this.googlePreferredBtn();
    },
    addNoopener: function() {
      var aTags = $('a');
      var ua = window.navigator.userAgent.toLowerCase();
      // IE11はnoopenerがサポートしていないので除外(念の為IE11以下も)
      var isIE = (~ua.indexOf('msie') || ~ua.indexOf('trident'));
      if (!isIE) {
        aTags.each(function(){
          if ($(this).attr('href') === undefined) return false;
          try {
            var host = new URL($(this).attr('href')).host;
            if (host.indexOf('times.abema.tv') > -1) {
              $(this).removeAttr('target').removeAttr('rel');
            } else if (host.indexOf('abema.tv') > -1) {
              $(this).attr('target','_blank').removeAttr('rel');
            } else {
              $(this).attr('rel', 'noreferrer noopener');
            }
          } catch(e) {
            var href = $(this).attr('href');
            if (href.indexOf('/') > -1 || href.indexOf('#') > -1) {
              $(this).removeAttr('target').removeAttr('rel');
            } else if (href.indexOf('times.abema.tv') > -1) {
              $(this).removeAttr('target').removeAttr('rel');
            } else if (href.indexOf('abema.tv') > -1) {
              $(this).attr('target','_blank').removeAttr('rel');
            } else {
              $(this).attr('rel', 'noreferrer noopener');
            }
          }
        });
      }
    },
    lazyLoad: function() {
      observer = lozad('.lazy',{
        rootMargin: "10%"
      });
      observer.observe();
    },
    luminousGallery: function() {
      if ($('.js-gallery').length === 0) return;

      var galleryOpts = {
        arrowNavigation: true
      };

      var luminousOpts = {
        sourceAttribute: 'data-gallery-src'
      };

      new LuminousGallery(document.querySelectorAll('.js-gallery'), galleryOpts, luminousOpts);
    },
    smoothScroll: function() {
      //移動先 DOM のoffsetTopを返す
      var moveToPos = function moveToPos(button) {
        var anchorTo = button.getAttribute('data-anchor-to');
        var anchor = document.querySelector('[data-anchor="' + anchorTo + '"');
        var scrollTop = window.pageYOffset || document.documentElement.scrollTop;
        var offsetTop = anchor.getBoundingClientRect().top + scrollTop;
        return offsetTop;
      };

      //クリックイベント
      var clickEventHandler = function clickEventHandler(event) {
        event.preventDefault();
        var button = event.currentTarget;
        var durationMs = 300;
        var startTime = Date.now();

        // durationMs の時間をかけて moveToPos へ移動する。
        // 画像の遅延読み込みがあるため、都度 moveToPos は計算しなおす。
        var executeScroll = function executeScroll() {
          var progress = Math.min(1, (Date.now() - startTime) / durationMs);
          scrollY = moveToPos(button) * progress;
          window.scrollTo(0, scrollY);
          if (progress < 1) {
            requestAnimationFrame(executeScroll);
          }
        };
        executeScroll();
      };

      // data-anchor-to がついている dom に対して click イベントを貼る
      var anchorButtons = document.querySelectorAll('[data-anchor-to]');
      if (anchorButtons) {
        Array.prototype.forEach.call(anchorButtons, function (button) {
          button.addEventListener('click', clickEventHandler);
        });
        // h2には不要なのでイベント削除
        anchorButtons = document.querySelectorAll('.js-article-body > h2[data-anchor-to]');
        if (anchorButtons) {
          Array.prototype.forEach.call(anchorButtons, function (button) {
            button.removeEventListener('click', clickEventHandler);
          });
        }
      }
      // urlにハッシュがあった場合
      if (location.hash) {
        var hash = location.hash.substr(1);
        var target = $(".js-anchor-list > li[data-anchor-to='" + hash + "']");
        // 目次がない記事ページパターン用
        if (target.length == 0 && $('.js-article-body').length) {
          target = $(".js-article-body > h2[data-anchor-to='" + hash + "']");
        }
        if (target.length > 0) {
          var func = function(){};
          var obj = {
            currentTarget:target[0],
            preventDefault:func
          };
          clickEventHandler(obj);
        }
      }
    },
    switchRanking: function() {
      var $tab = $('.js-tab-item');
      var $tabBlock = $('.js-tab-block');
      $tab.on("click", function() {
        var tabGroup = $(this).parents('.js-tab-group');
        var tabBtn = tabGroup.find($tab);
        var tabContents = tabGroup.find($tabBlock);
        tabBtn.removeClass('is-active');
        $(this).addClass('is-active');
        var elmIndex = tabBtn.index(this);
        tabContents.removeClass('is-show');
        tabContents.eq(elmIndex).addClass('is-show');
      })
    },
    headerNav: function() {
      var $triggerBtn = $('.js-hamburger-menu__open');
      var $headerNav = $('.js-hamburger-menu');
      var $closeBtn = $('.js-hamburger-menu__close');
      $triggerBtn.on('click', function(){
        $headerNav.css('right', '0');
      });
      $closeBtn.on('click', function(){
        $headerNav.css('right', '');
      });
    },
    search: function () {
      $('.js-search-text').keydown(function() {
        if (event.keyCode === 13) {
          location.href = '/list/search/' + encodeURIComponent($(this).val());
        }
      });
    },
    switchMiniCalendarTab: function() {
      var $tab = $('.js-mini-calendar-tab');
      var $content = $('.js-mini-calendar-content');
      $tab.on("click", function() {
        $tab.removeClass('is-current');
        $(this).addClass('is-current');
        $content.removeClass('is-current');
        $('.js-mini-calendar-content[data-date="' + $(this).attr('data-date') + '"]').addClass('is-current');
      });
    },
    language: function() {
      $('.js-language').on('click', function(){
        if ($(this).hasClass('is-open')) {
          $(this).removeClass('is-open');
        } else {
          $(this).addClass('is-open');
        }
      });
    },
    previousLink: function() {
        $('a[data-previous_link]').on('click', function(event){
          var url = new URL(location.href);
          if ($(this).attr('href').indexOf(url.origin) > -1) {
            url = new URL($(this).attr('href'));
          } else {
            url = new URL(url.origin + $(this).attr('href'));
          }
          url.searchParams.append('previous_link', $(this).attr('data-previous_link'));
          $(this).attr('href', url.href);
        });
    },
    googlePreferredBtn: function() {
      if ($('.google-preferred-btn').length === 0) return;

      (window.PREFERRED_SOURCE = window.PREFERRED_SOURCE || []).push(function (preferredSource) {
        preferredSource.init({ theme: 'light', lang: 'ja' });

        $('.google-preferred-btn').on('click', function () {
          preferredSource.addPreferredSource();
        });
      });
    }
  };
  TOOLS.init();

  // 期間限定
  // nowonair
  const spLayoutFlag = $(window).width() < 560 ? true : false;
  if ($('.js-nowonair-fixed').length) {
    var $nowonair = $('.js-nowonair-fixed');
    var $nowonairCloseBtn = $('.js-nowonair-fixed-close');
    if (!spLayoutFlag) {
      if ($('.js-send-customers-banner').length) {
        $('.js-send-customers-banner').css('bottom','220px');
        $nowonair.find('.js-nowonair-fixed-link').css('display','flex');
        $nowonair.find('.js-nowonair-fixed-close').css('display','block');
      } else {
        $nowonair.find('.js-nowonair-fixed-link').css('display','flex');
        $nowonair.find('.js-nowonair-fixed-close').css('display','block');
      }
    }
    $nowonairCloseBtn.on('click' , function(e){
      $nowonair.fadeOut();
      e.preventDefault();
    });
  }
});