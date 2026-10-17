/* Lumbre · prototipo navegable del loop (paso 14, MAT-223).
   Un solo estado (S), una función de render por pantalla y delegación de clics con data-act.
   Copy: el de design/copy/copy.json (ids en los comentarios cuando el texto es nuevo). */
(function () {
  'use strict';

  // ---------- Íconos (trazo, currentColor). La estrella de cuatro puntas es solo de la chispa: no está acá. ----------
  var I = {
    plus: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"><path d="M12 5v14M5 12h14"/></svg>',
    search: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><circle cx="11" cy="11" r="6.5"/><path d="m20 20-4.2-4.2"/></svg>',
    chevL: '<svg viewBox="0 0 12 20" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="M10 2 2 10l8 8"/></svg>',
    arrowL: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M20 12H5m6-7-7 7 7 7"/></svg>',
    chevR: '<svg class="chev" viewBox="0 0 8 14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m1 1 6 6-6 6"/></svg>',
    close: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round"><path d="M6 6l12 12M18 6 6 18"/></svg>',
    check: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="m5 12.5 4.5 4.5L19 7.5"/></svg>',
    checkCircle: '<svg viewBox="0 0 24 24" fill="currentColor"><circle cx="12" cy="12" r="11"/><path d="m7 12.5 3.5 3.5L17 9" fill="none" stroke="var(--on-accent)" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></svg>',
    mic: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><rect x="9" y="3" width="6" height="12" rx="3"/><path d="M5 11a7 7 0 0 0 14 0M12 18v3"/></svg>',
    link: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M10 14a4.5 4.5 0 0 0 6.4 0l3-3a4.5 4.5 0 0 0-6.4-6.4l-1 1"/><path d="M14 10a4.5 4.5 0 0 0-6.4 0l-3 3a4.5 4.5 0 0 0 6.4 6.4l1-1"/></svg>',
    photo: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round"><rect x="3" y="5" width="18" height="14" rx="3"/><circle cx="9" cy="10" r="1.6"/><path d="m4 17 5-4.5 4 3.5 3-2.5 4 3.5"/></svg>',
    text: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M4 6h16M4 11h16M4 16h10"/></svg>',
    code: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m8 7-5 5 5 5M16 7l5 5-5 5"/></svg>',
    pen: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round"><path d="M4 20l1-4L16 5l3 3L8 19z"/></svg>',
    chart: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M4 20V10M10 20V4M16 20v-7M22 20H2"/></svg>',
    shapes: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round"><circle cx="8" cy="8" r="4.5"/><rect x="12" y="12" width="9" height="9" rx="1.5"/></svg>',
    compass: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="m15.5 8.5-2 5-5 2 2-5z"/></svg>',
    person: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9"><circle cx="12" cy="9" r="4.5"/><path d="M4 21c1.5-4 4.5-6 8-6s6.5 2 8 6" stroke-linecap="round"/></svg>',
    bookmark: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M6 3h12v18l-6-4-6 4z"/></svg>',
    share: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 15V3m-4 4 4-4 4 4M5 12v7a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2v-7"/></svg>',
    lock: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round"><rect x="5" y="10" width="14" height="11" rx="2.5"/><path d="M8 10V7a4 4 0 0 1 8 0v3"/></svg>',
    apple: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M16.4 12.6c0-2.4 2-3.5 2-3.6-1.1-1.6-2.8-1.8-3.4-1.8-1.4-.1-2.8.9-3.5.9-.7 0-1.8-.8-3-.8-1.5 0-3 .9-3.8 2.3-1.6 2.8-.4 7 1.2 9.3.8 1.1 1.7 2.4 2.9 2.3 1.2 0 1.6-.7 3-.7s1.8.7 3 .7c1.3 0 2.1-1.1 2.8-2.3.9-1.3 1.3-2.6 1.3-2.6s-2.5-1-2.5-3.7zM14.1 5.6c.6-.8 1.1-1.9 1-3-.9 0-2.1.6-2.7 1.4-.6.7-1.1 1.8-1 2.9 1.1.1 2.1-.5 2.7-1.3z"/></svg>',
    google: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"><path d="M20 12.2h-8M20 12.2A8 8 0 1 1 17.7 6.3"/></svg>'
  };

  // ---------- Datos ----------
  var PROFILES = [
    { id: 'software', name: 'Software y apps', desc: 'Productos, features y arquitectura', icon: 'code', cats: ['Software', 'Producto'], ex: 'Ej.: Los PR chicos se revisan más rápido y con menos errores' },
    { id: 'content', name: 'Contenido y escritura', desc: 'Guiones, hilos, ensayos y ficción', icon: 'pen', cats: ['Escritura', 'Narrativa'], ex: 'Ej.: Un buen gancho deja una pregunta abierta' },
    { id: 'business', name: 'Negocios', desc: 'Modelos, servicios y oportunidades', icon: 'chart', cats: ['Negocios', 'Marketing'], ex: 'Ej.: Cobrar por suscripción cambia quién te elige' },
    { id: 'design', name: 'Diseño', desc: 'Interfaces, marca y producto físico', icon: 'shapes', cats: ['Diseño', 'Interfaces'], ex: 'Ej.: Lo que se ve primero es lo que parece importar' },
    { id: 'curiosity', name: 'Curiosidad libre', desc: 'Ideas por el gusto de pensarlas', icon: 'compass', cats: ['Ciencia', 'Historia'], ex: 'Ej.: Las hormigas encuentran el camino más corto dejando rastros' }
  ];
  var EXTRA_CATS = ['Naturaleza', 'Psicología', 'Música'];
  var SPARK = {
    a: { cat: 'Medios', title: 'Formato podcast' }, b: { cat: 'Historia', title: 'Ruinas romanas' },
    title: 'Podcast × ruinas',
    body: 'Un episodio por capa de excavación: cada uno cuenta una época de la misma ciudad con lo que quedó enterrado.'
  };
  var LIBRARY = [
    { id: 'lib1', title: 'Formato podcast', thesis: 'Una conversación larga genera confianza que un anuncio no logra.', principle: 'La atención sostenida construye vínculo.', cat: 'Medios', source: 'De la biblioteca de Lumbre', spark: true },
    { id: 'lib2', title: 'Ruinas romanas', thesis: 'Lo que queda de una ciudad cuenta cómo vivía la gente mejor que sus documentos.', principle: 'Los restos materiales guardan lo que nadie escribió.', cat: 'Historia', source: 'De la biblioteca de Lumbre', spark: true }
  ];
  var EXISTING = [
    { id: 'e1', title: 'Escasez intencional', thesis: 'Limitar la oferta sube el valor percibido y la atención.', principle: 'Lo escaso parece más valioso.', cat: 'Marketing', source: 'De un link' },
    { id: 'e2', title: 'Onda verde de semáforos', thesis: 'Sincronizar semáforos crea un flujo continuo a velocidad constante.', principle: 'Coordinar los tiempos de varias etapas evita las esperas entre ellas.', cat: 'Urbanismo', source: 'Texto' },
    { id: 'e3', title: 'Separación ciclónica', thesis: 'Un flujo en espiral separa partículas por fuerza centrífuga, sin filtro.', principle: 'Un movimiento rotatorio ordena elementos por su masa.', cat: 'Ingeniería', source: 'De un link' },
    { id: 'e4', title: 'Fermentación lenta', thesis: 'El tiempo transforma ingredientes simples en sabores complejos sin agregar nada.', principle: 'La espera es un ingrediente.', cat: 'Cocina', source: 'Nota de voz' }
  ];
  var GATES = { // cuenta.gate.*
    spark_extra: 'Las chispas extra se ganan guardando neuronas, y se guardan en tu cuenta. Creala gratis: lo que ya guardaste pasa con vos.',
    distill: 'Destilar lee links, fotos y PDFs y saca las neuronas por vos. Con una cuenta gratis tenés pruebas todos los meses.',
    planner: 'El planificador es parte de Lumbre Pro, y Pro va con una cuenta. Creala primero: lo que guardaste pasa con vos.',
    pro: 'Para suscribirte a Lumbre Pro necesitás una cuenta, así Pro te sigue a cualquier teléfono.',
    limit: 'Llegaste a las 10 neuronas de hoy como invitado. Con una cuenta gratis guardás hasta 30 por día.'
  };
  var TASKS = [
    { id: 'onboarding_completed', text: 'Completa el onboarding' },
    { id: 'neuron_saved', text: 'Guarda una idea desde Capturar' },
    { id: 'neuron_opened', text: 'La encuentra en la Red y la abre' },
    { id: 'spark_revealed', text: 'Enciende la chispa de hoy' },
    { id: 'spark_saved', text: 'Guarda la chispa' },
    { id: 'paywall_viewed', text: 'Encuentra qué tiene Pro' },
    { id: 'account_created', text: 'Crea su cuenta (si quiere)' }
  ];

  function fresh() {
    return {
      screen: 'welcome', tab: 'today', sub: null, overlay: null,
      plan: 'none', accountPurpose: null, consent: null, profiles: [],
      seeds: [{ text: '', cat: '' }, { text: '', cat: '' }, { text: '', cat: '' }], hour: 8, push: null,
      spark: 'pending', sparkCircuit: null, neurons: [], circuits: [], captures: 0, savedToday: 0,
      nudge: 'none', capture: null, search: '', catFilter: null, acct: null, gate: null, afterAccount: null,
      t0: Date.now(), log: [], done: {}
    };
  }
  var S = fresh();
  var opts = { existing: false, reduced: false };

  // ---------- Utilidades ----------
  function esc(s) { return String(s == null ? '' : s).replace(/[&<>"]/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]; }); }
  function $(sel) { return document.querySelector(sel); }
  function isAndroid() { return document.body.dataset.platform === 'android'; }
  function isGuest() { return S.plan === 'guest'; }
  function hourText() { return (S.hour < 10 ? '0' : '') + S.hour + ':00'; }
  function today() {
    var t = new Intl.DateTimeFormat('es-AR', { weekday: 'long', day: 'numeric', month: 'long' }).format(new Date());
    return t.charAt(0).toUpperCase() + t.slice(1);
  }
  function longDate() { return new Intl.DateTimeFormat('es-AR', { day: 'numeric', month: 'long', year: 'numeric' }).format(new Date()); }
  function log(event, detail) {
    var s = Math.round((Date.now() - S.t0) / 1000);
    S.log.push({ t: s, event: event, detail: detail || '' });
    if (TASKS.some(function (t) { return t.id === event; })) S.done[event] = S.done[event] || s;
    renderPanel();
  }
  function toast(text) {
    var el = document.createElement('div');
    el.className = 'toast' + (isAndroid() ? ' toast--md' : '');
    el.setAttribute('role', 'status');
    el.innerHTML = I.check + '<span>' + esc(text) + '</span>';
    $('#tel').appendChild(el);
    setTimeout(function () { el.remove(); }, 2200);
  }
  function back(label) {
    return '<button class="back" data-act="back">' + (isAndroid() ? I.arrowL : I.chevL + '<span>' + esc(label) + '</span>') + '</button>';
  }
  function primary(label, act, extra) {
    return '<button class="ch-btn ch-btn--primary btn-full" data-act="' + act + '"' + (extra || '') + '>' + label + '</button>';
  }
  function secondary(label, act, extra) {
    return '<button class="ch-btn ch-btn--secondary btn-full" data-act="' + act + '"' + (extra || '') + '>' + label + '</button>';
  }
  function mini(o) { return window.mini(o || {}); }
  function synapse(cls) {
    // La sinapsis completa con grupos animables (izquierda, derecha y estrella).
    var svg = window.arte('sinapsis-completa');
    var i = 0;
    svg = svg.replace(/<path class="n-active"/g, function () { i++; return '<path class="n-active ' + (i === 1 ? 'syn-l' : 'syn-r') + '"'; });
    svg = svg.replace('<path class="n-spark"', '<path class="n-spark syn-star"');
    return '<div class="syn-full rv ' + (cls || '') + '">' + svg + '</div>';
  }
  function pairhead() {
    return '<div class="pairhead"><div><span>' + SPARK.a.cat + '</span><b>' + SPARK.a.title + '</b></div><div class="r"><span>' + SPARK.b.cat + '</span><b>' + SPARK.b.title + '</b></div></div>';
  }

  // ---------- Pantallas de entrada y onboarding ----------
  function welcome() {
    return '<div class="welcome">' +
      '<div class="welcome__wm" data-art="wordmark" role="img" aria-label="Lumbre"></div>' +
      '<div class="welcome__pair" aria-label="Ejemplo: onda verde de semáforos por code review">' +
        '<div class="welcome__card"><span>Urbanismo</span><b>Onda verde de semáforos</b></div>' +
        '<div class="welcome__syn" data-art="sinapsis"></div>' +
        '<div class="welcome__card"><span>Software</span><b>Code review</b></div></div>' +
      '<h1>Donde se encienden las ideas</h1>' +
      '<p>Guardá lo que te inspira. Cada mañana, dos de tus neuronas se conectan y salta una chispa.</p></div>' +
      '<div class="footer-bar">' + primary('Empezar', 'start') + secondary('Crear cuenta o entrar', 'entry-account') + '</div>';
  }
  function progress(n) {
    var h = '<div class="progress" role="img" aria-label="Paso ' + n + ' de 4">';
    for (var i = 1; i <= 4; i++) h += '<i class="' + (i <= n ? 'on' : '') + '"></i>';
    return h + '</div>';
  }
  function obBack() { return '<div class="navbar-inline">' + back('Atrás') + '</div>'; }
  function obProfile() {
    var h = obBack() + progress(1) + '<h1 class="ob-title">¿Qué querés crear?</h1><p class="ob-sub">Elegí hasta dos. Lo podés cambiar cuando quieras.</p>';
    PROFILES.forEach(function (p) {
      var on = S.profiles.indexOf(p.id) >= 0;
      h += '<button class="opt' + (on ? ' is-on' : '') + '" data-act="profile" data-arg="' + p.id + '" aria-pressed="' + on + '">' +
        '<span class="opt__ic">' + I[p.icon] + '</span><span><b>' + p.name + '</b><span>' + p.desc + '</span></span>' +
        (on ? '<span class="opt__check">' + I.checkCircle + '</span>' : '') + '</button>';
    });
    return '<div class="has-footer">' + h + '</div><div class="footer-bar">' + primary('Continuar', 'to-seeds', S.profiles.length ? '' : ' disabled') + '</div>';
  }
  function suggestedCats() {
    var cats = [];
    S.profiles.forEach(function (id) { PROFILES.filter(function (p) { return p.id === id; })[0].cats.forEach(function (c) { cats.push(c); }); });
    if (!cats.length) cats = ['Software', 'Negocios'];
    return cats.concat(EXTRA_CATS).slice(0, 5);
  }
  function seedCount() { return S.seeds.filter(function (s) { return s.text.trim(); }).length; }
  function seedButtonLabel() {
    var n = seedCount();
    return n <= 1 ? 'Guardar neurona y seguir' : 'Guardar ' + n + ' neuronas y seguir';
  }
  function obSeeds() {
    var p = PROFILES.filter(function (x) { return x.id === S.profiles[0]; })[0] || PROFILES[0];
    var h = obBack() + progress(2) + '<h1 class="ob-title">Tus primeras neuronas</h1><p class="ob-sub">Algo que leíste, viste o pensaste. Cada idea que guardás es una neurona, y con estas sale tu primera chispa.</p>';
    S.seeds.forEach(function (s, i) {
      h += '<div class="seed"><div class="seed__lbl"><span>Neurona ' + (i + 1) + '</span></div>' +
        '<textarea class="field" rows="2" data-seed="' + i + '" placeholder="' + esc(i === 0 ? p.ex : 'Algo que leíste, viste o pensaste') + '" aria-label="Neurona ' + (i + 1) + '">' + esc(s.text) + '</textarea>' +
        '<input class="field" style="margin-top:8px;min-height:40px;padding:8px 12px;font-size:15px" data-seedcat="' + i + '" placeholder="Categoría (ej.: Urbanismo)" value="' + esc(s.cat) + '" aria-label="Categoría de la neurona ' + (i + 1) + '">' +
        '<div class="chips" aria-label="Categorías sugeridas">' + suggestedCats().map(function (c) {
          return '<button class="chip-btn' + (s.cat === c ? ' is-on' : '') + '" data-act="seedcat" data-arg="' + i + '|' + c + '">' + c + '</button>';
        }).join('') + '</div></div>';
    });
    h += '<p class="tip">Mejor si son de temas distintos: así se conectan mundos lejanos. Podés dictarlas con el micrófono del teclado.</p>';
    var n = seedCount();
    return '<div class="has-footer">' + h + '</div><div class="footer-bar">' +
      '<p class="tip" id="seedNote" style="margin:0 0 4px;' + (n > 0 && n < 3 ? '' : 'display:none') + '">Con tres la primera chispa sale mejor, pero podés seguir y sumar más después.</p>' +
      primary('<span id="seedBtn">' + seedButtonLabel() + '</span>', 'to-hour', n ? '' : ' disabled id="seedGo"').replace('data-act="to-hour"', 'data-act="to-hour" id="seedGo"') + '</div>';
  }
  function obHour() {
    return obBack() + progress(3) + '<h1 class="ob-title">¿A qué hora querés tu chispa?</h1>' +
      '<p class="ob-sub">Todos los días, a esta hora, dos de tus neuronas se conectan y salta una chispa.</p>' +
      '<div class="timebox" role="group" aria-label="Hora de la chispa"><button data-act="hour" data-arg="-1" aria-label="Más temprano">−</button><output>' + hourText() + '</output><button data-act="hour" data-arg="1" aria-label="Más tarde">+</button></div>' +
      '<p class="tip" style="margin-top:12px">La mayoría la elige a la mañana, antes de arrancar el día. La podés cambiar en Perfil.</p>' +
      '<div class="footer-bar">' + primary('Continuar', 'to-push') + '</div>';
  }
  function obPush() {
    return obBack() + progress(4) + '<h1 class="ob-title">Te avisamos cuando esté lista</h1>' +
      '<p class="ob-sub">Un aviso por día, a la hora que elegiste. Nada más.</p>' +
      '<div class="notif" aria-label="Ejemplo de aviso"><div class="notif__ic" data-art="icono-app"></div><div style="flex:1"><b>Lumbre <small>' + hourText() + '</small></b><span style="font-weight:600">Tu chispa de hoy está lista</span><span>Dos neuronas de tu red se conectaron. Entrá a ver qué chispa salió.</span></div></div>' +
      '<p class="tip">Si preferís sin avisos, la chispa te espera igual en Hoy.</p>' +
      '<div class="footer-bar">' + primary('Avisame', 'push-yes') + secondary('Ahora no', 'push-no') + '</div>';
  }

  // ---------- App principal ----------
  function meter() {
    var refill = 'Se recarga mañana a las ' + hourText();
    if (S.spark === 'pending') {
      return '<div class="meter">' + mini({ lit: true }) + '<div><b>1 chispa para encender</b><span>' + refill + '</span></div></div>';
    }
    var earn = '';
    if (S.plan === 'free') {
      var got = S.savedToday % 3;
      earn = '<div class="dots" aria-label="' + got + ' de 3 neuronas para la próxima chispa extra">' + [0, 1, 2].map(function (i) { return mini({ dim: i >= got, size: 18 }); }).join('') + '</div>';
      var left = 3 - got;
      return '<div class="meter">' + mini({ dim: true }) + '<div><b>Usaste las chispas de hoy</b><span>Guardá ' + left + (left === 1 ? ' neurona' : ' neuronas') + ' para ganar 1 extra</span></div>' + earn + '</div>';
    }
    return '<div class="meter">' + mini({ dim: true }) + '<div><b>Usaste las chispas de hoy</b><span>' + refill + '</span></div></div>';
  }
  function sparkActions() {
    return '<div class="row-actions">' +
      (S.spark === 'saved' ? '' : '<button class="ch-btn ch-btn--primary ch-btn--sm" data-act="save-spark">Guardar idea</button>') +
      '<button class="ch-btn ch-btn--secondary ch-btn--sm" data-act="plan">Planificar</button>' +
      '<button class="ch-btn ch-btn--secondary ch-btn--sm" data-act="share" aria-label="Compartir">' + I.share + '</button>' +
      (S.spark === 'saved' ? '' : '<button class="ch-btn ch-btn--ghost ch-btn--sm" data-act="not-useful">No me sirve</button>') + '</div>';
  }
  function todayScreen() {
    var h = '<div class="scr__net" data-art="red-encabezado"></div><h1 class="large-title">Hoy</h1><p class="date">' + today() + '</p>';
    if (S.nudge === 'show') {
      h += '<div class="nudge" role="note"><b>Tu primera chispa ya está. Creá tu cuenta para que tu red no dependa de este teléfono.</b>' +
        '<div class="row-actions"><button class="ch-btn ch-btn--primary" data-act="account-create" data-arg="nudge">Crear cuenta</button><button class="ch-btn ch-btn--secondary" data-act="nudge-later">Más tarde</button></div></div>';
    }
    h += '<div class="pad">' + meter();
    if (S.spark === 'pending') {
      h += '<div class="stage">' + pairhead() + synapse() + '<b>Tu chispa de hoy está lista</b><span>Dos neuronas tuyas de mundos distintos están por conectarse.</span>' +
        '<button class="ch-btn ch-btn--primary btn-full" data-act="ignite"><i class="ch-dot"></i>Encender la chispa</button></div>';
    } else if (S.spark === 'discarded') {
      h += '<div class="empty-block"><div data-art="estado-sin-chispa"></div><h3>Ya usaste la chispa de hoy</h3><p>Marcaste que esta no te sirve. Con eso elegimos mejor la de mañana.</p></div>';
    } else {
      h += '<article class="sparkopen">' + pairhead() + synapse() + '<h2 class="spark-title">' + SPARK.title + '</h2><p class="spark-body">' + SPARK.body + '</p>' + sparkActions() +
        (S.spark === 'saved' ? '<div class="statusline">' + I.bookmark + (S.sparkCircuit ? 'Guardada en “' + esc(S.sparkCircuit) + '”' : 'Guardada') + '</div>' : '') + '</article>';
      h += '<h3 class="sub-h">Otra chispa</h3>';
      if (isGuest()) {
        h += '<p class="muted" style="margin-bottom:12px">Creá tu cuenta para ganar chispas extra guardando neuronas.</p>' + secondary('Pedir otra chispa', 'extra');
      } else if (S.plan === 'pro') {
        h += secondary('Pedir otra chispa', 'extra') + '<p class="muted" style="margin-top:8px;font-size:13px">Te quedan 9 chispas extra hoy.</p>';
      } else {
        var extras = Math.min(2, Math.floor(S.savedToday / 3));
        h += extras ? secondary('Pedir otra chispa', 'extra') + '<p class="muted" style="margin-top:8px;font-size:13px">' + (extras === 1 ? 'Te queda 1 chispa extra hoy.' : 'Te quedan 2 chispas extra hoy.') + '</p>'
          : '<p class="muted">Cada 3 neuronas que guardás hoy ganás una chispa extra, hasta 2 por día.</p><button class="ch-btn ch-btn--ghost" style="padding-left:0" data-act="paywall">Con Pro, hasta 10 por día</button>';
      }
    }
    return h + '</div>';
  }
  function categories() {
    var seen = {};
    return S.neurons.map(function (n) { return n.cat; }).filter(function (c) { if (!c || seen[c]) return false; seen[c] = 1; return true; });
  }
  function redScreen() {
    var list = S.neurons.filter(function (n) {
      var q = S.search.trim().toLowerCase();
      return (!S.catFilter || n.cat === S.catFilter) && (!q || (n.title + ' ' + n.thesis + ' ' + n.cat).toLowerCase().indexOf(q) >= 0);
    });
    var h = '<div class="scr__net" data-art="red-encabezado"></div><h1 class="large-title">Red</h1>' +
      '<label class="search">' + I.search + '<input id="search" class="field" style="background:transparent;padding:0;min-height:0" placeholder="Buscar ideas, no palabras" value="' + esc(S.search) + '" aria-label="Buscar ideas, no palabras"></label>' +
      '<div class="chiprow" aria-label="Filtrar por categoría"><button class="chip-btn' + (!S.catFilter ? ' is-on' : '') + '" data-act="cat" data-arg="">Todos</button>' +
      categories().map(function (c) { return '<button class="chip-btn' + (S.catFilter === c ? ' is-on' : '') + '" data-act="cat" data-arg="' + esc(c) + '">' + esc(c) + '</button>'; }).join('') + '</div>';
    if (!S.neurons.length) {
      return h + '<div class="empty-block"><div data-art="estado-red-vacia"></div><h3>Todavía no hay neuronas</h3><p>Guardá una frase, un link o una nota de voz para tener material que combinar.</p><button class="ch-btn ch-btn--primary" data-act="capture">' + I.plus + 'Capturar</button></div>';
    }
    if (!list.length) {
      return h + '<div class="empty-block"><h3>Nada por acá</h3><p>' + (S.catFilter ? 'Probá con otras palabras o sacá el filtro de categoría.' : 'Probá con otras palabras: la búsqueda entiende ideas, no solo coincidencias.') + '</p></div>';
    }
    h += '<p class="section-label" style="margin-top:4px">Neuronas</p><ul class="axonlist pad">';
    list.forEach(function (n) {
      h += '<li><span style="cursor:pointer" data-act="open-neuron" data-arg="' + n.id + '">' + mini({ lit: false }) + '</span><div style="cursor:pointer;flex:1" data-act="open-neuron" data-arg="' + n.id + '" role="button" aria-label="' + esc(n.title) + '"><span>' + esc(n.cat || 'Sin categoría') + '</span><b>' + esc(n.title) + '</b><p>' + esc(n.thesis) + '</p><span style="margin-top:4px">' + esc(n.source) + ' · ' + (n.when || 'hoy') + '</span></div></li>';
    });
    return h + '</ul>';
  }
  function neuronScreen(id) {
    var n = S.neurons.filter(function (x) { return x.id === id; })[0];
    if (!n) return redScreen();
    var h = '<div class="navbar-inline">' + back('Red') + '<button class="navbtn" aria-label="Más">···</button></div><div class="detail">' +
      '<p class="cat">' + esc(n.cat || 'Sin categoría') + '</p><h1>' + esc(n.title) + '</h1><p class="thesis">' + esc(n.thesis) + '</p>';
    if (n.principle) h += '<h4>Principio</h4><p class="principle">' + esc(n.principle) + '</p>';
    h += '<h4>Fuente</h4><p class="muted">' + esc(n.source) + (n.source.indexOf('biblioteca') >= 0 ? '' : ' · Guardado el ' + longDate()) + '</p>';
    h += '<h4>Chispas donde aparece</h4>';
    h += n.spark && S.spark !== 'pending'
      ? '<ul class="axonlist"><li>' + mini({ lit: true }) + '<div><b>' + SPARK.title + '</b><span>Hoy</span></div></li></ul>'
      : '<p class="muted">Todavía no se conectó con otra neurona. Cuando aparezca en una chispa, la vas a ver acá.</p>';
    h += '<div style="margin-top:24px">' + secondary('Combinar con…', 'combine') + '<p class="muted" style="font-size:13px;margin-top:8px">' + (S.plan === 'pro' ? 'Elegí otra neurona y Lumbre enciende una chispa con las dos.' : 'Con Lumbre Pro elegís qué neuronas se conectan.') + '</p></div></div>';
    return h;
  }
  function circuitsScreen() {
    var h = '<div class="scr__net" data-art="red-encabezado"></div><h1 class="large-title">Circuitos</h1>';
    if (!S.circuits.length) {
      return h + '<div class="empty-block" style="padding-top:40px"><div data-art="estado-sin-circuitos"></div><h3>Todavía no hay circuitos</h3><p>Un circuito junta las ideas que querés llevar adelante. Creá uno o guardá una chispa desde Hoy y elegí dónde sumarla.</p><button class="ch-btn ch-btn--primary" data-act="new-circuit">Crear circuito</button></div>';
    }
    h += '<ul class="axonlist pad">';
    S.circuits.forEach(function (c) {
      var count = S.sparkCircuit === c ? 1 : 0;
      h += '<li>' + mini({ lit: count > 0 }) + '<div><b>' + esc(c) + '</b><span>' + count + (count === 1 ? ' idea' : ' ideas') + '</span></div></li>';
    });
    h += '</ul><div class="pad" style="margin-top:16px">' + secondary('Nuevo circuito', 'new-circuit') +
      (S.plan !== 'pro' ? '<p class="muted" style="font-size:13px;margin-top:8px">Con el plan gratis tenés un circuito. Con Pro, todos los que quieras.</p>' : '') + '</div>';
    return h;
  }
  function profileScreen() {
    var planName = { guest: 'Invitado', free: 'Gratis', pro: 'Pro' }[S.plan];
    var profNames = S.profiles.map(function (id) { return PROFILES.filter(function (p) { return p.id === id; })[0].name; }).join(' y ') || 'Sin elegir';
    var limit = isGuest() ? 10 : S.plan === 'pro' ? 200 : 30;
    var theme = document.documentElement.dataset.theme;
    var h = '<h1 class="large-title">Perfil</h1>';
    if (isGuest()) {
      h += '<div class="nudge"><b style="font-size:17px;line-height:22px;margin-bottom:4px">Creá tu cuenta para no perder tus ideas</b><p class="muted" style="margin-bottom:12px">Hoy usás Lumbre como invitado. Con una cuenta, tus ideas quedan a salvo si cambiás o perdés el teléfono.</p>' +
        '<button class="ch-btn ch-btn--primary" data-act="account-create" data-arg="profile">Crear cuenta</button></div>';
    }
    h += '<p class="section-label">Suscripción</p><div class="list-group"><div class="li">Plan<small>' + planName + '</small></div>' +
      (S.plan === 'pro' ? '<button class="li">Administrar suscripción' + I.chevR + '</button>' : '<button class="li" data-act="paywall"><span><b style="font-weight:600">Lumbre Pro</b><br><small style="text-align:left;display:block">Hasta 10 chispas por día, destilación automática y el planificador</small></span>' + I.chevR + '</button>') + '</div>';
    h += '<p class="section-label">Tu chispa</p><div class="list-group"><div class="li">Perfil creativo<small>' + esc(profNames) + '</small></div><div class="li">Hora de la chispa<small>' + hourText() + '</small></div><div class="li">Avisos<small>' + (S.push ? 'Activados' : isAndroid() ? 'Activalos en Configuración' : 'Activalos en Ajustes') + '</small></div></div>';
    h += '<p class="section-label">Tus cupos</p><div class="list-group"><div class="li">Capturas de hoy<small>' + (limit - S.captures) + ' de ' + limit + '</small></div>' +
      (isGuest() ? '' : '<div class="li">Destilaciones del mes<small>' + (S.plan === 'pro' ? '300 de 300' : '3 de 3') + '</small></div>') +
      '<div class="li">Circuitos<small>' + S.circuits.length + ' de ' + (S.plan === 'pro' ? '∞' : '1') + '</small></div></div>';
    h += '<p class="section-label">Apariencia</p><div class="list-group">' +
      [['light', 'Gris'], ['dark', 'Grafito']].map(function (t) { return '<button class="li" data-act="theme" data-arg="' + t[0] + '">' + t[1] + '<span class="radio' + (theme === t[0] ? ' is-on' : '') + '"></span></button>'; }).join('') + '</div>';
    h += '<p class="section-label">Privacidad</p><div class="list-group"><button class="li">Privacidad y datos' + I.chevR + '</button></div>';
    h += '<div class="list-group" style="margin-top:20px"><button class="li" data-act="signout" style="justify-content:center;color:var(--danger)">Cerrar sesión</button></div><p class="tip" style="text-align:center;margin-top:12px">Lumbre 1.0 (prototipo)</p>';
    return h;
  }

  function tabbar() {
    var tabs = [['today', 'Hoy', '<span data-art="tab-hoy" style="width:24px"></span>'], ['red', 'Red', '<span data-art="tab-red" style="width:24px"></span>'],
      ['circuits', 'Circuitos', '<span data-art="tab-circuitos" style="width:24px"></span>'], ['profile', 'Perfil', '<span style="width:24px;display:block">' + I.person + '</span>']];
    var md = isAndroid();
    return '<div class="tabbar"><nav class="ch-nav' + (md ? ' ch-nav--md' : '') + '" aria-label="Pestañas">' + tabs.map(function (t) {
      var on = S.tab === t[0] && !S.sub;
      return '<button class="ch-nav__i' + (on ? ' is-on' : '') + '" data-act="tab" data-arg="' + t[0] + '" aria-label="' + t[1] + '"' + (on ? ' aria-current="page"' : '') + '>' + t[2] + (md && !on ? '' : t[1]) + '</button>';
    }).join('') + '</nav><button class="ch-add' + (md ? ' ch-add--md' : '') + '" data-act="capture" aria-label="Capturar">' + I.plus + '</button></div>';
  }

  // ---------- Overlays ----------
  function sheet(inner, full) {
    return '<div class="scrim" data-act="close-overlay"></div><div class="sheet' + (full ? ' sheet--full' : '') + '" role="dialog" aria-modal="true"><div class="sheet__grab"></div>' + inner + '</div>';
  }
  function consentSheet() {
    return sheet('<h2>Tus ideas y la IA</h2><div class="sheet-body"><p>Para destilar lo que guardás y encender las chispas, Lumbre manda el texto de tus ideas a Claude, una IA de Anthropic.</p>' +
      '<p class="muted">Solo se manda lo necesario para cada chispa: tus ideas y tu perfil creativo.</p><p class="muted">Podés cambiar esto cuando quieras en Perfil &gt; Privacidad.</p>' +
      '<p class="muted">Si no aceptás, podés guardar ideas igual, pero las chispas y la destilación necesitan este permiso.</p>' +
      '<p><a href="#" data-act="noop" style="font-size:15px">Leer la política de privacidad</a></p></div>' +
      '<div class="btns">' + primary('Acepto', 'consent-yes') + secondary('No acepto', 'consent-no') + '</div>');
  }
  function accountSheet() {
    var a = S.acct;
    var create = a.purpose !== 'signin';
    var title = a.purpose === 'entry' ? 'Creá tu cuenta o entrá' : create ? 'Creá tu cuenta' : 'Entrá a tu cuenta';
    var body = a.purpose === 'entry' ? 'Te mandamos un código a tu email, sin contraseñas. Si todavía no tenés cuenta, la creamos con ese email.'
      : 'Tu red queda a salvo aunque cambies o perdés el teléfono. Todo lo que guardaste como invitado pasa a tu cuenta.'.replace('perdés', 'pierdas');
    var h = '<div class="sheet-nav"><span></span><button class="circlebtn" data-act="close-overlay" aria-label="Cerrar">' + I.close + '</button></div>' +
      '<h2 style="font-size:28px;line-height:34px">' + title + '</h2><div class="sheet-body"><p class="muted" style="font-size:17px;line-height:24px">' + body + '</p></div>';
    if (a.step === 'email') {
      h += '<div class="btns">' + (isAndroid()
        ? '<button class="ch-btn ch-btn--secondary btn-full" data-act="provider" data-arg="Google">' + I.google + 'Continuar con Google</button>'
        : '<button class="ch-btn ch-btn--secondary btn-full" data-act="provider" data-arg="Apple">' + I.apple + 'Continuar con Apple</button><button class="ch-btn ch-btn--secondary btn-full" data-act="provider" data-arg="Google">' + I.google + 'Continuar con Google</button>') +
        '</div><p class="tip" style="text-align:center;margin:14px 16px 6px">o con tu email</p>' +
        '<div class="field-wrap"><input class="field" id="email" type="email" inputmode="email" autocomplete="off" placeholder="Tu email" aria-label="Email" value="' + esc(a.email || '') + '"></div>' +
        '<div class="btns" style="padding-top:12px">' + primary('Mandarme el código', 'send-code') + '</div>';
    } else {
      h += '<div class="sheet-body"><p style="font-size:15px;line-height:20px">Te mandamos un código de 6 dígitos a ' + esc(a.email) + '. Escribilo acá o tocá el link del mail en este teléfono.</p></div>' +
        '<div class="field-wrap"><input class="field" id="code" inputmode="numeric" maxlength="6" placeholder="Código" aria-label="Código de 6 dígitos" style="font-size:22px;letter-spacing:.2em"></div>' +
        '<div class="row-actions" style="padding:4px 8px"><button class="ch-btn ch-btn--ghost" data-act="noop">Mandar otro código</button><button class="ch-btn ch-btn--ghost" data-act="change-email">Cambiar el email</button></div>' +
        '<div class="btns">' + primary(create ? 'Crear cuenta' : 'Entrar', 'verify') + '</div>';
    }
    return sheet(h, true);
  }
  function gateSheet() {
    return sheet('<div class="sheet-body" style="padding-top:8px"><span style="display:block;width:32px;height:32px;color:var(--ink);margin-bottom:8px">' + I.lock + '</span></div><h2>Esto es con cuenta</h2>' +
      '<div class="sheet-body"><p>' + GATES[S.gate] + '</p></div><div class="btns">' + primary('Crear cuenta', 'account-create', ' data-arg="gate-' + S.gate + '"') + secondary('Ahora no', 'close-overlay') + '</div>');
  }
  function revealOverlay() {
    return '<div class="reveal-veil" data-act="reveal-outside"><div class="reveal-panel' + (opts.reduced ? ' is-done' : ' play') + '" id="rpanel" role="dialog" aria-modal="true" aria-label="Tu chispa de hoy">' +
      '<div class="reveal-panel__top"><span>Tu chispa de hoy</span><button class="circlebtn" data-act="close-reveal" aria-label="Cerrar">' + I.close + '</button></div>' +
      '<div style="margin-top:12px">' + pairhead() + '</div>' + synapse() +
      '<h2 class="spark-title reveal-title" style="margin:8px 0 10px">' + SPARK.title + '</h2><p class="spark-body reveal-body">' + SPARK.body + '</p>' +
      '<div class="after" style="margin-top:16px">' + sparkActions() + '</div></div></div>';
  }
  function saveSheet() {
    var opts2 = ['', ].concat(S.circuits);
    var sel = S.saveChoice == null ? '' : S.saveChoice;
    var h = '<div class="sheet-nav"><button class="navbtn" data-act="close-overlay">Cancelar</button><span class="t">Guardar idea</span><span style="width:70px"></span></div>' +
      '<p class="section-label" style="margin-top:8px">Dónde la guardás</p><div class="list-group">' +
      opts2.map(function (c) {
        return '<button class="li" data-act="save-choice" data-arg="' + esc(c) + '"><span>' + (c ? esc(c) + '<br><small style="text-align:left;display:block">' + (S.sparkCircuit === c ? '1 idea' : '0 ideas') + '</small>' : 'Sin circuito<br><small style="text-align:left;display:block">Queda en tus ideas guardadas</small>') + '</span><span class="radio' + (sel === c ? ' is-on' : '') + '"></span></button>';
      }).join('') + '</div>';
    if (!S.circuits.length || S.plan === 'pro') {
      h += '<p class="section-label">Nuevo circuito</p><div class="field-wrap" style="display:flex;gap:8px"><input class="field" id="newcircuit" placeholder="Nombre del circuito" aria-label="Nombre del circuito"><button class="ch-btn ch-btn--secondary" data-act="create-circuit-inline">Crear</button></div>';
    } else {
      h += '<p class="tip" style="margin-top:8px">Con el plan gratis tenés un circuito. Con Pro, todos los que quieras.</p>';
    }
    h += '<div class="btns" style="padding-top:20px">' + primary('Guardar idea', 'confirm-save') + '</div>';
    return sheet(h);
  }
  function feedbackSheet() {
    return sheet('<h2>¿Por qué no te sirve?</h2><div class="sheet-body"><p class="muted">Con esto elegimos mejor las próximas chispas.</p></div><div class="list-group">' +
      ['Es obvia', 'No tiene que ver conmigo', 'Ya la había tenido'].map(function (r) { return '<button class="li" data-act="feedback" data-arg="' + r + '">' + r + I.chevR + '</button>'; }).join('') +
      '</div><div class="btns">' + secondary('Cancelar', 'close-overlay') + '</div>');
  }
  function shareSheet() {
    return sheet('<div class="sheet-nav"><span></span><span class="t">Tarjeta para compartir</span><button class="circlebtn" data-act="close-overlay" aria-label="Cerrar">' + I.close + '</button></div>' +
      '<div class="share-prev" aria-label="Vista previa de la tarjeta"><div class="net" data-art="red-historia"></div><div class="p"><div data-art="sinapsis-completa"></div><h5>' + SPARK.title + '</h5><i>' + SPARK.body + '</i>' +
      '<div class="sig"><span data-art="marca" style="width:24px"></span>Lumbre<b></b></div></div></div>' +
      '<div class="btns">' + primary(I.share + 'Compartir imagen', 'share-go') + '</div>');
  }
  function captureSheet() {
    var c = S.capture;
    var kinds = [['text', 'Texto', I.text], ['voice', 'Voz', I.mic], ['link', 'Link', I.link], ['photo', 'Foto', I.photo]];
    var h = '<div class="sheet-nav"><button class="navbtn" data-act="close-overlay">Cancelar</button><span class="t">Nueva neurona</span><span style="width:70px"></span></div>' +
      '<div class="seg-ctl" role="tablist" aria-label="Tipo">' + kinds.map(function (k) { return '<button role="tab" aria-selected="' + (c.kind === k[0]) + '" class="' + (c.kind === k[0] ? 'is-on' : '') + '" data-act="kind" data-arg="' + k[0] + '">' + k[2] + k[1] + '</button>'; }).join('') + '</div>';
    if (c.kind === 'voice') {
      h += '<div class="mic"><button data-act="dictate" aria-label="Dictar">' + I.mic + '</button><span>' + (c.text ? 'Tocá para seguir dictando' : 'Tocá y decí tu idea') + '</span></div>' +
        '<p class="field-lbl">Transcripción</p><div class="field-wrap"><textarea class="field" id="ctext" placeholder="Lo que dictes aparece acá. Podés corregirlo.">' + esc(c.text) + '</textarea></div><p class="tip" style="margin-top:6px">Se transcribe en el teléfono. El audio no se guarda.</p>';
    } else if (c.kind === 'link') {
      h += '<div class="field-wrap"><input class="field" id="curl" placeholder="https://" value="' + esc(c.url) + '" aria-label="Link"></div>' +
        '<p class="field-lbl">¿Qué idea te deja esto?</p><div class="field-wrap"><textarea class="field" id="ctext" placeholder="En una línea, con tus palabras">' + esc(c.text) + '</textarea></div>' +
        '<div class="toggle-row"><span>Destilar automáticamente</span><button class="switch' + (c.distill ? ' is-on' : '') + '" data-act="distill" role="switch" aria-checked="' + c.distill + '" aria-label="Destilar automáticamente"></button></div>' +
        '<p class="tip">' + (isGuest() ? 'La destilación es con cuenta. Creala desde Perfil y probala gratis.' : S.plan === 'pro' ? 'Ilimitado en Pro' : 'Lumbre lee el contenido y saca de 1 a 3 neuronas. Te quedan 3 pruebas este mes.') + '</p>';
    } else if (c.kind === 'photo') {
      h += '<div class="row-actions" style="padding:0 16px"><button class="ch-btn ch-btn--secondary" data-act="noop">' + I.photo + 'Elegir foto</button><button class="ch-btn ch-btn--secondary" data-act="noop">Escanear página</button></div>' +
        '<p class="field-lbl">¿Qué idea te deja esto?</p><div class="field-wrap"><textarea class="field" id="ctext" placeholder="En una línea, con tus palabras">' + esc(c.text) + '</textarea></div>' +
        '<p class="tip" style="margin-top:6px">' + (isAndroid() ? 'La foto queda en tu galería.' : 'La foto queda en tu fototeca.') + ' En el prototipo no se elige una foto real: escribí la idea.</p>';
    } else {
      h += '<div class="field-wrap"><textarea class="field" id="ctext" style="min-height:140px" placeholder="¿Qué idea te quedó dando vueltas?" aria-label="Idea">' + esc(c.text) + '</textarea></div>' +
        '<p class="field-lbl"><span></span><span class="cnt" id="ccount">' + c.text.length + ' de 600 caracteres</span></p>';
    }
    var cats = categories();
    h += '<p class="field-lbl">Categoría</p><div class="field-wrap"><input class="field" id="ccat" placeholder="Por ejemplo: Marketing" value="' + esc(c.cat) + '" aria-label="Categoría"></div>' +
      (cats.length ? '<div class="chiprow" style="padding-top:8px">' + cats.map(function (x) { return '<button class="chip-btn' + (c.cat === x ? ' is-on' : '') + '" data-act="ccat" data-arg="' + esc(x) + '">' + esc(x) + '</button>'; }).join('') + '</div>'
        : '<p class="tip" style="margin-top:8px">Todavía no tenés categorías: se crean a medida que guardás neuronas.</p>') +
      '<div class="btns" style="padding-top:12px">' + primary('Guardar neurona', 'save-neuron') + '</div>';
    return sheet(h, true);
  }
  function paywallSheet() {
    var annual = S.planChoice !== 'monthly';
    var benefits = ['Hasta 10 chispas por día, y elegís qué neuronas se conectan', 'Destilación automática de links, fotos y PDFs', 'Planificador para bajar cada idea a tareas', 'Circuitos ilimitados'];
    var h = '<div class="sheet-nav"><span></span><button class="circlebtn" data-act="close-overlay" aria-label="Cerrar">' + I.close + '</button></div><div class="paywall">';
    if (S.plan === 'pro') {
      return sheet(h + '<h1>Ya tenés Lumbre Pro</h1><p class="lead2">Gracias por bancar Lumbre. Tu suscripción se administra desde ' + (isAndroid() ? 'Google Play.' : 'tu cuenta de Apple.') + '</p>' + primary('Listo', 'close-overlay') + '</div>', true);
    }
    h += '<h1>Lumbre Pro</h1><p class="lead2">Más chispas por día y un plan para cada idea.</p><ul class="benefits">' + benefits.map(function (b) { return '<li>' + I.check + '<span>' + b + '</span></li>'; }).join('') + '</ul>' +
      '<div class="plans" role="radiogroup" aria-label="Planes">' +
      '<button class="plan' + (annual ? ' is-on' : '') + '" role="radio" aria-checked="' + annual + '" data-act="plan-choice" data-arg="annual"><span class="badge">Ahorrás 40%</span><b>Anual</b><div class="price">US$ 49,99</div><span>por año</span><span>US$ 4,17 por mes · 7 días gratis</span></button>' +
      '<button class="plan' + (!annual ? ' is-on' : '') + '" role="radio" aria-checked="' + !annual + '" data-act="plan-choice" data-arg="monthly"><b style="margin-top:22px">Mensual</b><div class="price">US$ 6,99</div><span>por mes</span><span>Cancelás cuando quieras</span></button></div>' +
      primary(annual ? 'Probar 7 días gratis' : 'Suscribirme por US$ 6,99 al mes', 'buy') +
      '<p class="tip" style="margin:8px 0 0;text-align:center">' + (annual ? 'Después, US$ 49,99 por año. Cancelás cuando quieras.' : 'US$ 6,99 por mes. Cancelás cuando quieras.') + '</p>' +
      '<p class="legal">' + (isAndroid() ? 'La suscripción se cobra en tu cuenta de Google Play y se renueva sola al mismo precio, salvo que la canceles antes del fin del período.' : 'La suscripción se cobra en tu cuenta de Apple y se renueva sola al mismo precio, salvo que la canceles al menos 24 horas antes del fin del período.') + '</p>' +
      '<div class="links"><a href="#" data-act="noop">Restaurar compras</a><a href="#" data-act="noop">Términos</a><a href="#" data-act="noop">Privacidad</a></div></div>';
    return sheet(h, true);
  }
  function newCircuitSheet() {
    return sheet('<h2>Nuevo circuito</h2><div class="field-wrap"><input class="field" id="ncname" placeholder="Nombre del circuito" aria-label="Nombre del circuito"></div><div class="btns" style="padding-top:12px">' + primary('Crear', 'create-circuit') + secondary('Cancelar', 'close-overlay') + '</div>');
  }
  function alertBox(title, body, buttons) {
    return '<div class="scrim"></div><div class="alert' + (isAndroid() ? ' alert--md' : '') + '" role="alertdialog" aria-modal="true"><h4>' + title + '</h4><p>' + body + '</p><div class="alert__btns">' + buttons + '</div></div>';
  }
  function sysPush() {
    return '<div class="scrim" style="background:rgba(14,14,16,.35)"></div><div class="sys-alert" role="alertdialog">' +
      (isAndroid() ? '<h4>¿Permitir que Lumbre te envíe notificaciones?</h4><p></p><div class="b"><button data-act="push-allow">Permitir</button><button data-act="push-deny">No permitir</button></div>'
        : '<h4>“Lumbre” quiere enviarte notificaciones</h4><p>Las notificaciones pueden incluir alertas, sonidos y globos en el ícono.</p><div class="b"><button data-act="push-deny">No permitir</button><button class="strong" data-act="push-allow">Permitir</button></div>') + '</div>';
  }

  // ---------- Render ----------
  function render() {
    var tel = $('#tel');
    tel.classList.toggle('tel--android', isAndroid());
    var scr = $('#screen');
    var top = scr.scrollTop, keep = scr.dataset.view === viewKey();
    var html;
    switch (S.screen) {
      case 'welcome': html = welcome(); break;
      case 'ob-profile': html = obProfile(); break;
      case 'ob-seeds': html = obSeeds(); break;
      case 'ob-hour': html = obHour(); break;
      case 'ob-push': html = obPush(); break;
      default:
        html = S.sub ? neuronScreen(S.sub) : { today: todayScreen, red: redScreen, circuits: circuitsScreen, profile: profileScreen }[S.tab]();
    }
    scr.innerHTML = html;
    scr.dataset.view = viewKey();
    scr.scrollTop = keep ? top : 0;
    $('#chrome').innerHTML = S.screen === 'app' ? tabbar() : '';
    renderOverlay();
    window.pintarArte(tel);
  }
  function viewKey() { return S.screen + '|' + S.tab + '|' + (S.sub || ''); }
  function renderOverlay() {
    var o = S.overlay, h = '';
    $('#screen').classList.toggle('is-veiled', o === 'reveal');
    $('#chrome').classList.toggle('is-veiled', o === 'reveal');
    var map = { consent: consentSheet, account: accountSheet, gate: gateSheet, reveal: revealOverlay, save: saveSheet, feedback: feedbackSheet, share: shareSheet, capture: captureSheet, paywall: paywallSheet, 'new-circuit': newCircuitSheet, push: sysPush };
    if (o === 'signout') {
      h = alertBox('¿Cerrar sesión?', isGuest() ? 'Usás Lumbre como invitado: si cerrás sesión, perdés tus neuronas, chispas y circuitos.' : 'Tus ideas quedan guardadas en tu cuenta. Vas a poder volver a entrar cuando quieras.',
        '<button data-act="close-overlay">Cancelar</button><button class="danger" data-act="signout-yes">Cerrar sesión</button>');
    } else if (o && map[o]) h = map[o]();
    $('#overlay').innerHTML = h;
    window.pintarArte($('#overlay'));
    window.pintarMinis($('#overlay'));
    var focus = $('#overlay [autofocus], #overlay #email, #overlay #code');
    if (focus) setTimeout(function () { focus.focus(); }, 50);
  }
  function renderPanel() {
    $('#tasks').innerHTML = TASKS.map(function (t) { var d = S.done[t.id]; return '<li class="' + (d != null ? 'done' : '') + '">' + t.text + (d != null ? ' · ' + d + ' s' : '') + '</li>'; }).join('');
    $('#log').innerHTML = S.log.slice().reverse().map(function (l) { return '<li><time>' + l.t + ' s</time><span><code>' + l.event + '</code> ' + esc(l.detail) + '</span></li>'; }).join('') || '<li><span>Todavía nada.</span></li>';
  }
  function open(o) { S.overlay = o; renderOverlay(); }
  function close() { S.overlay = null; renderOverlay(); }

  // ---------- Acciones ----------
  function finishOnboarding() {
    if (S.plan === 'none') S.plan = 'guest';
    S.neurons = S.seeds.filter(function (s) { return s.text.trim(); }).map(function (s, i) {
      return { id: 's' + i, title: titleOf(s.text), thesis: s.text.trim(), cat: s.cat.trim(), source: 'Texto', when: 'hoy' };
    }).concat(LIBRARY);
    S.screen = 'app'; S.tab = 'today'; S.sub = null; S.overlay = null;
    log('onboarding_completed', S.plan === 'guest' ? 'como invitado' : 'con cuenta');
    render();
  }
  function titleOf(text) {
    var t = text.trim().split(/[.!?\n]/)[0];
    return t.length > 48 ? t.slice(0, 46).replace(/\s+\S*$/, '') + '…' : t;
  }
  function afterAccount() {
    var from = S.acct.from;
    var wasGuest = isGuest();
    S.overlay = null;
    if (from === 'entry') {
      if (opts.existing) {
        S.plan = 'free'; S.profiles = ['software', 'business']; S.neurons = EXISTING.concat(LIBRARY); S.screen = 'app'; S.tab = 'today';
        log('account_signed_in', 'cuenta existente');
        render(); return;
      }
      S.plan = 'free';
      log('account_created', 'desde la bienvenida');
      if (S.consent == null) { S.overlay = 'consent'; renderOverlay(); return; }
      S.screen = 'ob-profile'; render(); return;
    }
    S.plan = 'free';
    if (S.nudge === 'show') S.nudge = 'done';
    log('account_created', 'desde ' + from + (wasGuest ? ' (invitado → cuenta, conserva todo)' : ''));
    render();
    toast('Listo: tu red ya está en tu cuenta'); // cuenta.created
  }
  function startReveal() {
    open('reveal');
    log('spark_reveal_started');
    var p = $('#rpanel');
    var hapticAt = opts.reduced ? 0 : 650, doneAt = opts.reduced ? 200 : 900;
    setTimeout(function () { log('haptic', 'success'); flashHaptic(); }, hapticAt);
    setTimeout(function () {
      if (!p) return;
      p.classList.add('is-done');
      S.spark = 'revealed';
      log('spark_revealed', opts.reduced ? 'reducir movimiento' : '');
    }, doneAt);
  }
  function flashHaptic() {
    var tel = $('#tel');
    tel.animate([{ transform: 'translateX(0)' }, { transform: 'translateX(-2px)' }, { transform: 'translateX(2px)' }, { transform: 'translateX(0)' }], { duration: 160 });
  }
  function needAccount(reason) { S.gate = reason; log('account_gate', reason); open('gate'); }
  function saveNeuron() {
    var c = S.capture;
    var text = ($('#ctext') ? $('#ctext').value : c.text).trim();
    var cat = ($('#ccat') ? $('#ccat').value : c.cat).trim();
    if (c.kind === 'link') {
      var url = ($('#curl') ? $('#curl').value : '').trim();
      if (!/^https?:\/\/\S+\.\S+/.test(url) && !/^\S+\.\S+/.test(url)) { toastWarn('Revisá el link: no parece válido.'); return; }
      if (c.distill && isGuest()) { needAccount('distill'); return; }
      if (!text && !c.distill) { toastWarn('¿Qué idea te deja esto?'); return; }
      if (!text) text = 'Una idea sacada de ' + url.replace(/^https?:\/\//, '').split('/')[0];
    }
    if (!text) { toastWarn('¿Qué idea te quedó dando vueltas?'); return; }
    var limit = isGuest() ? 10 : S.plan === 'pro' ? 200 : 30;
    if (S.captures >= limit) { if (isGuest()) needAccount('limit'); else toastWarn('Llegaste al límite de hoy. Mañana podés seguir.'); return; }
    S.captures++; S.savedToday++;
    var src = { text: 'Texto', voice: 'Nota de voz', link: 'De un link', photo: 'Imagen' }[c.kind];
    S.neurons.unshift({ id: 'n' + Date.now(), title: titleOf(text), thesis: text, cat: cat, source: src, when: 'recién', principle: c.distill ? 'Destilado por Lumbre (simulado en el prototipo).' : null });
    S.overlay = null;
    log('neuron_saved', src + (cat ? ' · ' + cat : ''));
    render();
    toast('Neurona guardada');
  }
  function toastWarn(text) {
    var el = document.createElement('div');
    el.className = 'toast' + (isAndroid() ? ' toast--md' : '');
    el.setAttribute('role', 'alert');
    el.style.bottom = '120px';
    el.textContent = text;
    $('#tel').appendChild(el);
    setTimeout(function () { el.remove(); }, 2200);
  }

  var ACTIONS = {
    noop: function () {},
    start: function () { log('guest_entered'); if (S.consent == null) open('consent'); else { S.screen = 'ob-profile'; render(); } },
    'entry-account': function () { S.acct = { purpose: 'entry', from: 'entry', step: 'email' }; log('account_sheet', 'bienvenida'); open('account'); },
    'consent-yes': function () { S.consent = true; log('ai_consent', 'acepta'); S.overlay = null; S.screen = 'ob-profile'; render(); },
    'consent-no': function () { S.consent = false; log('ai_consent', 'no acepta'); S.overlay = null; S.screen = 'ob-profile'; render(); },
    back: function () {
      if (S.sub) { S.sub = null; render(); return; }
      var order = ['welcome', 'ob-profile', 'ob-seeds', 'ob-hour', 'ob-push'];
      var i = order.indexOf(S.screen); if (i > 0) { S.screen = order[i - 1]; render(); }
    },
    profile: function (id) {
      var i = S.profiles.indexOf(id);
      if (i >= 0) S.profiles.splice(i, 1);
      else if (S.profiles.length < 2) S.profiles.push(id);
      else { toastWarn('Ya elegiste dos. Sacá uno para elegir este.'); return; }
      render();
    },
    'to-seeds': function () { log('onboarding_profile', S.profiles.join(', ')); S.screen = 'ob-seeds'; render(); },
    seedcat: function (arg) { var p = arg.split('|'); S.seeds[+p[0]].cat = S.seeds[+p[0]].cat === p[1] ? '' : p[1]; render(); },
    'to-hour': function () { log('onboarding_seeds', seedCount() + ' ideas'); S.screen = 'ob-hour'; render(); },
    hour: function (d) { S.hour = (S.hour + (+d) + 24) % 24; render(); },
    'to-push': function () { log('onboarding_hour', hourText()); S.screen = 'ob-push'; render(); },
    'push-yes': function () { open('push'); },
    'push-no': function () { S.push = false; log('push', 'ahora no'); finishOnboarding(); },
    'push-allow': function () { S.push = true; log('push', 'permitido'); finishOnboarding(); },
    'push-deny': function () { S.push = false; log('push', 'no permitido'); finishOnboarding(); },
    tab: function (t) { S.tab = t; S.sub = null; render(); },
    capture: function () { S.capture = { kind: 'text', text: '', url: '', cat: '', distill: false }; log('capture_opened'); open('capture'); },
    kind: function (k) { syncCapture(); S.capture.kind = k; renderOverlay(); },
    ccat: function (c) { syncCapture(); S.capture.cat = S.capture.cat === c ? '' : c; renderOverlay(); },
    distill: function () { syncCapture(); if (isGuest()) { needAccount('distill'); return; } S.capture.distill = !S.capture.distill; renderOverlay(); },
    dictate: function () { syncCapture(); S.capture.text = (S.capture.text ? S.capture.text + ' ' : '') + 'Los mercados de pulgas funcionan como un algoritmo de recomendación sin datos.'; renderOverlay(); },
    'save-neuron': saveNeuron,
    'close-overlay': function () { if (S.overlay === 'reveal') return; close(); },
    ignite: function () { startReveal(); },
    'reveal-outside': function (_, ev) { if (ev.target.classList.contains('reveal-veil') && S.spark !== 'pending') ACTIONS['close-reveal'](); },
    'close-reveal': function () { S.overlay = null; render(); },
    'save-spark': function () { S.saveChoice = S.circuits[0] || ''; open('save'); },
    'save-choice': function (c) { S.saveChoice = c; renderOverlay(); },
    'create-circuit-inline': function () { var v = ($('#newcircuit').value || '').trim(); if (!v) return; S.circuits.push(v); S.saveChoice = v; log('circuit_created', v); renderOverlay(); },
    'confirm-save': function () {
      S.spark = 'saved'; S.sparkCircuit = S.saveChoice || null; S.overlay = null;
      log('spark_saved', S.sparkCircuit ? 'en ' + S.sparkCircuit : 'sin circuito');
      if (isGuest() && S.nudge === 'none') S.nudge = 'show';
      render(); toast('Idea guardada');
    },
    'nudge-later': function () { S.nudge = 'done'; log('account_nudge', 'más tarde'); render(); },
    plan: function () { log('planner_tapped'); if (isGuest()) needAccount('planner'); else if (S.plan !== 'pro') { log('paywall_viewed', 'planificador'); open('paywall'); } else toast('El planificador está en el paso 35'); },
    share: function () { log('share_opened'); open('share'); },
    'share-go': function () { log('spark_shared'); close(); toast('Imagen lista para compartir'); },
    'not-useful': function () { open('feedback'); },
    feedback: function (r) { S.spark = 'discarded'; log('spark_feedback', r); S.overlay = null; render(); toast('Gracias. Con esto elegimos mejor las próximas.'); },
    extra: function () { if (isGuest()) needAccount('spark_extra'); else toast('En el prototipo hay una sola chispa'); },
    paywall: function () { log('paywall_viewed', S.tab); open('paywall'); },
    'plan-choice': function (p) { S.planChoice = p; renderOverlay(); },
    buy: function () { if (isGuest()) { needAccount('pro'); return; } S.plan = 'pro'; log('pro_started', S.planChoice === 'monthly' ? 'mensual' : 'anual con prueba'); render(); open('paywall'); },
    'account-create': function (from) { S.acct = { purpose: 'create', from: from || 'perfil', step: 'email' }; log('account_sheet', from); open('account'); },
    provider: function (p) { log('account_provider', p); afterAccount(); },
    'send-code': function () {
      var v = ($('#email').value || '').trim();
      if (!/^\S+@\S+\.\S+$/.test(v)) { toastWarn('Revisá el email: no parece válido.'); return; }
      S.acct.email = v; S.acct.step = 'code'; renderOverlay();
    },
    'change-email': function () { S.acct.step = 'email'; renderOverlay(); },
    verify: function () {
      var v = ($('#code').value || '').replace(/\D/g, '');
      if (v.length !== 6) { toastWarn('El código no es correcto o ya venció. Revisalo o pedí otro.'); return; }
      afterAccount();
    },
    'open-neuron': function (id) { S.sub = id; log('neuron_opened', (S.neurons.filter(function (n) { return n.id === id; })[0] || {}).title); render(); },
    cat: function (c) { S.catFilter = c || null; render(); },
    combine: function () { if (S.plan === 'pro') toast('Combinar está en el paso 52'); else { log('paywall_viewed', 'combinar'); open('paywall'); } },
    'new-circuit': function () { if (S.circuits.length >= 1 && S.plan !== 'pro') { log('paywall_viewed', 'circuitos'); open('paywall'); return; } open('new-circuit'); },
    'create-circuit': function () { var v = ($('#ncname').value || '').trim(); if (!v) return; S.circuits.push(v); log('circuit_created', v); S.overlay = null; render(); },
    theme: function (t) { window.setTheme(t); render(); },
    signout: function () { open('signout'); },
    'signout-yes': function () { log('signed_out'); var keepLog = S.log, t0 = S.t0, done = S.done; S = fresh(); S.log = keepLog; S.t0 = t0; S.done = done; render(); }
  };
  function syncCapture() {
    if (!S.capture) return;
    if ($('#ctext')) S.capture.text = $('#ctext').value;
    if ($('#ccat')) S.capture.cat = $('#ccat').value;
    if ($('#curl')) S.capture.url = $('#curl').value;
  }

  // ---------- Eventos ----------
  document.addEventListener('DOMContentLoaded', function () {
    var tel = $('#tel');
    tel.addEventListener('click', function (ev) {
      var el = ev.target.closest('[data-act]');
      if (!el || !tel.contains(el) || el.disabled) return;
      if (el.tagName === 'A') ev.preventDefault();
      var fn = ACTIONS[el.dataset.act];
      if (fn) fn(el.dataset.arg, ev);
    });
    tel.addEventListener('input', function (ev) {
      var t = ev.target;
      if (t.dataset.seed != null) {
        S.seeds[+t.dataset.seed].text = t.value;
        var n = seedCount();
        $('#seedBtn').textContent = seedButtonLabel();
        $('#seedGo').disabled = !n;
        $('#seedNote').style.display = n > 0 && n < 3 ? '' : 'none';
      } else if (t.dataset.seedcat != null) {
        S.seeds[+t.dataset.seedcat].cat = t.value;
      } else if (t.id === 'ctext' && $('#ccount')) {
        var len = t.value.length;
        $('#ccount').textContent = len > 600 ? 'Te pasaste por ' + (len - 600) + ' caracteres. Dejá solo la idea (hasta 600).' : len + ' de 600 caracteres';
        $('#ccount').classList.toggle('over', len > 600);
      } else if (t.id === 'search') {
        S.search = t.value;
        var pos = t.selectionStart; render();
        var s = $('#search'); s.focus(); s.setSelectionRange(pos, pos);
      } else if (t.id === 'code' && t.value.replace(/\D/g, '').length === 6) {
        ACTIONS.verify();
      }
    });
    tel.addEventListener('keydown', function (ev) {
      if (ev.key === 'Enter' && ev.target.id === 'email') ACTIONS['send-code']();
      if (ev.key === 'Escape' && S.overlay && S.overlay !== 'reveal') close();
    });
    document.addEventListener('platformchange', function () { if ($('#screen')) { render(); fit(); } });

    $('#reset').addEventListener('click', function () { S = fresh(); render(); renderPanel(); });
    $('#hidepanel').addEventListener('click', function () {
      var p = $('.proto__panel'); var hidden = p.style.display === 'none';
      p.style.display = hidden ? '' : 'none';
    });
    $('#optExisting').addEventListener('change', function (e) { opts.existing = e.target.checked; });
    $('#optReduced').checked = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    opts.reduced = $('#optReduced').checked;
    $('#optReduced').addEventListener('change', function (e) { opts.reduced = e.target.checked; });
    $('#copylog').addEventListener('click', function () {
      var text = S.log.map(function (l) { return l.t + '\t' + l.event + '\t' + l.detail; }).join('\n');
      if (navigator.clipboard) navigator.clipboard.writeText(text).catch(function () {});
      $('#copylog').textContent = 'Copiado';
      setTimeout(function () { $('#copylog').textContent = 'Copiar registro'; }, 1500);
    });
    var jumps = [
      ['Bienvenida', function () { S.screen = 'welcome'; }],
      ['Perfil creativo', function () { S.screen = 'ob-profile'; }],
      ['Semillas', function () { S.screen = 'ob-seeds'; }],
      ['Hora', function () { S.screen = 'ob-hour'; }],
      ['Avisos', function () { S.screen = 'ob-push'; }],
      ['Hoy (invitado)', function () { quickApp('guest'); }],
      ['Hoy (cuenta free)', function () { quickApp('free'); }],
      ['Chispa revelada', function () { quickApp(S.plan === 'none' ? 'guest' : S.plan); S.spark = 'revealed'; }],
      ['Capturar', function () { quickApp(S.plan === 'none' ? 'guest' : S.plan); S.overlay = 'capture'; S.capture = { kind: 'text', text: '', url: '', cat: '', distill: false }; }],
      ['Red', function () { quickApp(S.plan === 'none' ? 'guest' : S.plan); S.tab = 'red'; }],
      ['Detalle de neurona', function () { quickApp(S.plan === 'none' ? 'guest' : S.plan); S.tab = 'red'; S.sub = S.neurons[0].id; }],
      ['Circuitos', function () { quickApp(S.plan === 'none' ? 'guest' : S.plan); S.tab = 'circuits'; }],
      ['Perfil', function () { quickApp(S.plan === 'none' ? 'guest' : S.plan); S.tab = 'profile'; }],
      ['Paywall', function () { quickApp(S.plan === 'none' ? 'guest' : S.plan); S.overlay = 'paywall'; }],
      ['Puerta de cuenta', function () { quickApp('guest'); S.gate = 'planner'; S.overlay = 'gate'; }]
    ];
    $('#jump').innerHTML = jumps.map(function (j, i) { return '<button data-j="' + i + '">' + j[0] + '</button>'; }).join('');
    $('#jump').addEventListener('click', function (ev) {
      var b = ev.target.closest('[data-j]'); if (!b) return;
      S.overlay = null; S.sub = null; jumps[+b.dataset.j][1](); render();
    });
    render(); renderPanel();
    fit(); window.addEventListener('resize', fit);
  });
  // El teléfono entra entero en la ventana (alto y ancho).
  function fit() {
    var wrap = $('.proto__phone'), tel = $('#tel');
    var w = tel.offsetWidth + 40, h = tel.offsetHeight + 40;
    var z = Math.min(1, (window.innerHeight - 16) / h, (Math.min(window.innerWidth, document.documentElement.clientWidth) - 16) / w);
    wrap.style.zoom = Math.max(0.4, z).toFixed(3);
  }
  function quickApp(plan) {
    if (S.screen !== 'app') {
      S.plan = plan; S.profiles = S.profiles.length ? S.profiles : ['software'];
      S.neurons = S.neurons.length ? S.neurons : EXISTING.concat(LIBRARY);
      S.screen = 'app'; S.tab = 'today';
    } else if (plan !== S.plan && (plan === 'guest' || plan === 'free')) S.plan = plan;
  }
})();
