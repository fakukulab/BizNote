(function () {
  var root = document.documentElement;
  function set(l) {
    root.setAttribute('data-lang', l);
    root.lang = l;
    try { localStorage.setItem('lang', l); } catch (e) {}
  }
  var saved = null;
  try { saved = localStorage.getItem('lang'); } catch (e) {}
  var q = new URLSearchParams(location.search).get('lang');
  set(q || saved || ((navigator.language || 'ko').toLowerCase().indexOf('ko') === 0 ? 'ko' : 'en'));
  document.addEventListener('DOMContentLoaded', function () {
    var b = document.getElementById('langBtn');
    if (b) b.addEventListener('click', function () {
      set(root.getAttribute('data-lang') === 'ko' ? 'en' : 'ko');
    });
  });
})();
