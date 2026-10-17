/* Lumbre · ayudas de los mockups: tema gris/grafito, plataforma iOS/Android y neuronas chicas.
   Botones: <button data-set-theme="light|dark">, <button data-set-platform="ios|android">. */
(function () {
  var KEY_THEME = 'lumbre.maqueta.theme', KEY_PLATFORM = 'lumbre.maqueta.platform';
  function read(k) { try { return localStorage.getItem(k); } catch (e) { return null; } }
  function write(k, v) { try { localStorage.setItem(k, v); } catch (e) {} }

  window.setTheme = function (t) {
    document.documentElement.dataset.theme = t;
    document.querySelectorAll('[data-set-theme]').forEach(function (b) {
      b.setAttribute('aria-pressed', String(b.dataset.setTheme === t));
    });
    write(KEY_THEME, t);
  };
  window.setPlatform = function (p) {
    document.body.dataset.platform = p;
    document.querySelectorAll('[data-set-platform]').forEach(function (b) {
      b.setAttribute('aria-pressed', String(b.dataset.setPlatform === p));
    });
    write(KEY_PLATFORM, p);
    document.dispatchEvent(new CustomEvent('platformchange', { detail: p }));
  };

  /* Neurona chica: la compacta en tinta; con núcleo rosa si está encendida, en border si está dormida. */
  window.mini = function (opts) {
    opts = opts || {};
    var cls = 'mini' + (opts.dim ? ' is-dim' : '');
    var size = opts.size ? ' style="width:' + opts.size + 'px;height:' + opts.size + 'px"' : '';
    return '<span class="' + cls + '"' + size + ' aria-hidden="true">' + window.arte('marca-compacta') +
      (opts.lit && !opts.dim ? '<i class="nuc"></i>' : '') + '</span>';
  };
  window.pintarMinis = function (root) {
    (root || document).querySelectorAll('[data-mini]').forEach(function (el) {
      if (el.dataset.done) return;
      var v = el.dataset.mini;
      el.outerHTML = window.mini({ lit: v === 'lit', dim: v === 'dim', size: el.dataset.size });
    });
  };

  document.addEventListener('DOMContentLoaded', function () {
    document.querySelectorAll('[data-set-theme]').forEach(function (b) {
      b.addEventListener('click', function () { window.setTheme(b.dataset.setTheme); });
    });
    document.querySelectorAll('[data-set-platform]').forEach(function (b) {
      b.addEventListener('click', function () { window.setPlatform(b.dataset.setPlatform); });
    });
    window.setTheme(read(KEY_THEME) || document.documentElement.dataset.theme || 'light');
    if (document.querySelector('[data-set-platform]')) window.setPlatform(read(KEY_PLATFORM) || document.body.dataset.platform || 'ios');
    if (window.pintarArte) window.pintarArte();
    window.pintarMinis();
  });
})();
