import Foundation

/// Page mobile servie par le Compagnon Téléphone.
/// Entièrement autonome (HTML + CSS + JS inline) : aucune ressource externe, donc fonctionne sans Internet.
enum PhoneCompanionWebPage {
    
    static let manifest = #"""
    {
      "name": "Recall Live",
      "short_name": "Recall",
      "display": "standalone",
      "background_color": "#0B0E14",
      "theme_color": "#0B0E14",
      "start_url": "/",
      "icons": []
    }
    """#
    
    static let html = #"""
    <!DOCTYPE html>
    <html lang="fr">
    <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover, user-scalable=no">
    <meta name="apple-mobile-web-app-capable" content="yes">
    <meta name="mobile-web-app-capable" content="yes">
    <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
    <meta name="theme-color" content="#0B0E14">
    <link rel="manifest" href="/manifest.json">
    <title>Recall Live</title>
    <style>
      :root {
        --accent: #00D9E6;
        --accent2: #3399FF;
        --bg: #0B0E14;
        --card: rgba(255,255,255,0.045);
        --card-border: rgba(255,255,255,0.08);
        --text: #F4F6FA;
        --muted: rgba(244,246,250,0.55);
        --faint: rgba(244,246,250,0.32);
        --green: #38EB61;
        --orange: #FF9E14;
        --red: #FF5252;
      }
      * { box-sizing: border-box; -webkit-tap-highlight-color: transparent; }
      html, body { margin: 0; padding: 0; background: var(--bg); color: var(--text);
        font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
        -webkit-font-smoothing: antialiased; overscroll-behavior-y: none; }
      body { min-height: 100vh; padding: env(safe-area-inset-top) env(safe-area-inset-right) env(safe-area-inset-bottom) env(safe-area-inset-left);
        background: radial-gradient(1200px 500px at 50% -200px, color-mix(in srgb, var(--accent) 18%, transparent), transparent 70%), var(--bg); }
      
      header { position: sticky; top: 0; z-index: 10; display: flex; align-items: center; gap: 10px;
        padding: 12px 16px 10px; background: color-mix(in srgb, var(--bg) 82%, transparent); backdrop-filter: blur(18px); -webkit-backdrop-filter: blur(18px);
        border-bottom: 1px solid var(--card-border); }
      .logo { width: 28px; height: 28px; border-radius: 50%; background: conic-gradient(from 0deg, #111 0 20%, #1e1e1e 20% 40%, #111 40% 60%, #1e1e1e 60% 80%, #111 80%);
        position: relative; flex: 0 0 auto; box-shadow: 0 0 0 1px rgba(255,255,255,0.08), 0 0 18px color-mix(in srgb, var(--accent) 35%, transparent); }
      .logo::after { content: ""; position: absolute; inset: 8px; border-radius: 50%; background: linear-gradient(135deg, var(--accent), var(--accent2)); }
      .brand { font-weight: 800; font-size: 17px; letter-spacing: -0.2px; }
      .brand small { display: block; font-size: 10px; font-weight: 700; color: var(--muted); letter-spacing: 1.4px; text-transform: uppercase; margin-top: 1px; }
      .conn { margin-left: auto; display: flex; align-items: center; gap: 6px; font-size: 11px; font-weight: 700; color: var(--muted); }
      .dot { width: 8px; height: 8px; border-radius: 50%; background: var(--red); box-shadow: 0 0 10px var(--red); transition: all .3s; }
      .dot.on { background: var(--green); box-shadow: 0 0 10px var(--green); }
      .dot.wait { background: var(--orange); box-shadow: 0 0 10px var(--orange); }
      
      main { padding: 14px 14px 32px; max-width: 720px; margin: 0 auto; }
      
      .now { position: relative; border-radius: 18px; padding: 16px 16px 14px; overflow: hidden;
        background: linear-gradient(160deg, color-mix(in srgb, var(--accent) 16%, var(--card)), var(--card) 60%);
        border: 1px solid color-mix(in srgb, var(--accent) 35%, var(--card-border)); box-shadow: 0 10px 40px rgba(0,0,0,0.35); }
      .now .label { display: flex; align-items: center; gap: 7px; font-size: 10px; font-weight: 800; letter-spacing: 1.5px; text-transform: uppercase; color: var(--accent); }
      .now .label .pulse { width: 7px; height: 7px; border-radius: 50%; background: var(--accent); animation: pulse 1.6s ease-in-out infinite; }
      .now.idle .label { color: var(--muted); } .now.idle .label .pulse { animation: none; background: var(--faint); }
      @keyframes pulse { 0%,100% { transform: scale(1); opacity: 1; } 50% { transform: scale(1.5); opacity: .45; } }
      .now .title { font-size: 22px; font-weight: 800; line-height: 1.15; margin: 10px 0 3px; letter-spacing: -0.3px; word-break: break-word; }
      .now .artist { font-size: 14px; color: var(--muted); font-weight: 600; }
      .now .meta { display: flex; gap: 8px; margin-top: 12px; flex-wrap: wrap; align-items: center; }
      .pill { display: inline-flex; align-items: center; gap: 5px; padding: 5px 10px; border-radius: 999px; font-size: 12px; font-weight: 800;
        background: rgba(255,255,255,0.07); border: 1px solid var(--card-border); }
      .pill.key { color: #0B0E14; border-color: transparent; }
      .pill .u { font-size: 9px; font-weight: 700; opacity: .6; letter-spacing: .6px; }
      .deck { margin-left: auto; font-size: 10px; font-weight: 800; color: var(--accent); letter-spacing: 1px; text-transform: uppercase; opacity: .9; }
      
      .bar { display: flex; align-items: center; gap: 8px; margin: 18px 2px 10px; flex-wrap: wrap; }
      .bar h2 { margin: 0; font-size: 12px; font-weight: 800; letter-spacing: 1.4px; text-transform: uppercase; color: var(--muted); }
      .bar .count { font-size: 12px; font-weight: 800; color: var(--accent); background: color-mix(in srgb, var(--accent) 16%, transparent); padding: 3px 9px; border-radius: 999px; }
      .chips { margin-left: auto; display: flex; gap: 5px; flex-wrap: wrap; }
      .chip { font-size: 10px; font-weight: 800; padding: 4px 8px; border-radius: 7px; background: color-mix(in srgb, var(--accent) 18%, transparent); color: var(--accent); letter-spacing: .4px; }
      .chip.fav { background: rgba(255,82,82,0.18); color: var(--red); }
      
      .list { display: flex; flex-direction: column; gap: 8px; }
      .row { display: grid; grid-template-columns: 26px 1fr auto; gap: 10px; align-items: center; padding: 11px 12px; border-radius: 14px;
        background: var(--card); border: 1px solid var(--card-border); transition: transform .15s; }
      .row:active { transform: scale(.985); }
      .row.top { border-color: color-mix(in srgb, var(--accent) 45%, var(--card-border)); background: linear-gradient(135deg, color-mix(in srgb, var(--accent) 12%, var(--card)), var(--card)); }
      .row.played { opacity: .5; }
      .row .idx { font-size: 12px; font-weight: 800; color: var(--faint); text-align: center; }
      .row.top .idx { color: var(--accent); }
      .row .t { font-size: 15px; font-weight: 700; line-height: 1.2; overflow: hidden; text-overflow: ellipsis; display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical; }
      .row .a { font-size: 12px; color: var(--muted); margin-top: 2px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
      .row .badges { display: flex; gap: 5px; margin-top: 6px; flex-wrap: wrap; }
      .b { font-size: 10px; font-weight: 800; padding: 2px 6px; border-radius: 5px; background: rgba(255,255,255,0.07); color: var(--muted); letter-spacing: .3px; }
      .b.direct { background: rgba(255,158,20,0.16); color: var(--orange); }
      .b.routine { background: color-mix(in srgb, var(--accent2) 20%, transparent); color: var(--accent2); }
      .b.variant { background: rgba(184,89,255,0.18); color: #C98BFF; }
      .b.favorite, .b.heart { background: rgba(255,82,82,0.16); color: var(--red); }
      .b.rel { background: color-mix(in srgb, var(--accent) 16%, transparent); color: var(--accent); }
      .b.boost { background: rgba(56,235,97,0.16); color: var(--green); }
      .b.played { background: rgba(255,255,255,0.08); color: var(--muted); }
      .row .right { display: flex; flex-direction: column; align-items: flex-end; gap: 5px; }
      .key { min-width: 44px; text-align: center; padding: 5px 8px; border-radius: 8px; font-size: 13px; font-weight: 900; color: #0B0E14; background: rgba(255,255,255,0.15); }
      .key.none { color: var(--faint); background: rgba(255,255,255,0.06); }
      .bpm { font-size: 13px; font-weight: 800; }
      .bpm small { font-size: 10px; font-weight: 700; color: var(--muted); margin-left: 3px; }
      .bpm .d { font-size: 10px; font-weight: 800; margin-left: 4px; }
      .bpm .d.up { color: var(--green); } .bpm .d.down { color: var(--orange); }
      
      .empty { text-align: center; padding: 48px 20px; color: var(--muted); font-size: 14px; line-height: 1.5; }
      .empty .ico { font-size: 38px; margin-bottom: 10px; opacity: .6; }
      .empty b { color: var(--text); display: block; font-size: 16px; margin-bottom: 4px; }
      
      .pinbox { max-width: 360px; margin: 60px auto; text-align: center; padding: 26px 20px; border-radius: 18px; background: var(--card); border: 1px solid var(--card-border); }
      .pinbox h1 { font-size: 18px; margin: 0 0 6px; } .pinbox p { color: var(--muted); font-size: 13px; margin: 0 0 16px; }
      .pinbox input { width: 100%; font-size: 26px; letter-spacing: 10px; text-align: center; padding: 12px; border-radius: 12px; border: 1px solid var(--card-border);
        background: rgba(0,0,0,0.3); color: var(--text); outline: none; font-weight: 800; }
      .pinbox button { margin-top: 12px; width: 100%; padding: 13px; border-radius: 12px; border: none; font-weight: 800; font-size: 15px;
        background: linear-gradient(135deg, var(--accent), var(--accent2)); color: #0B0E14; }
      .pinbox .err { color: var(--red); font-size: 12px; font-weight: 700; margin-top: 10px; min-height: 16px; }
      
      footer { text-align: center; color: var(--faint); font-size: 10px; padding: 18px 0 6px; letter-spacing: .4px; }
      .hidden { display: none !important; }
    </style>
    </head>
    <body>
    <header>
      <div class="logo"></div>
      <div class="brand">Recall<small>Live Companion</small></div>
      <div class="conn"><span id="dot" class="dot wait"></span><span id="connText">Connexion…</span></div>
    </header>
    
    <main>
      <section id="pin" class="pinbox hidden">
        <h1>Code PIN requis</h1>
        <p>Entrez le code affiché dans la fenêtre Compagnon Téléphone de Recall sur votre Mac.</p>
        <input id="pinInput" inputmode="numeric" autocomplete="one-time-code" maxlength="8" placeholder="••••">
        <button id="pinBtn">Connecter</button>
        <div id="pinErr" class="err"></div>
      </section>
      
      <section id="app" class="hidden">
        <div id="now" class="now idle">
          <div class="label"><span class="pulse"></span><span id="nowLabel">En attente</span><span id="deck" class="deck"></span></div>
          <div id="nowTitle" class="title">Lancez un morceau</div>
          <div id="nowArtist" class="artist">Les suggestions apparaîtront ici dès que votre logiciel DJ joue.</div>
          <div id="nowMeta" class="meta"></div>
        </div>
        
        <div class="bar">
          <h2 id="listTitle">Suggestions</h2>
          <span id="count" class="count">0</span>
          <div id="chips" class="chips"></div>
        </div>
        
        <div id="list" class="list"></div>
      </section>
    </main>
    <footer id="foot">Recall • 100 % local, sans Internet</footer>
    
    <script>
    (function () {
      var params = new URLSearchParams(location.search);
      var pin = params.get('pin') || localStorage.getItem('recall_pin') || '';
      if (params.get('pin')) {
        localStorage.setItem('recall_pin', pin);
        history.replaceState(null, '', location.pathname);
      }
      
      var $ = function (id) { return document.getElementById(id); };
      var es = null, lastJSON = '', wakeLock = null;
      
      function esc(s) { return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
        return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; }); }
      
      function setConn(state, text) {
        var d = $('dot'); d.className = 'dot ' + (state === 'on' ? 'on' : state === 'wait' ? 'wait' : '');
        $('connText').textContent = text;
      }
      
      function showPin(err) {
        $('pin').classList.remove('hidden'); $('app').classList.add('hidden');
        $('pinErr').textContent = err || '';
        setConn('off', 'PIN requis');
        setTimeout(function () { $('pinInput').focus(); }, 50);
      }
      
      function matchBadge(t) {
        var m = t.matchType;
        if (m === 'direct') return t.count > 0 ? '<span class="b direct">🔥 ' + t.count + '×</span>' : '';
        if (m === 'routine') return '<span class="b routine">🔁 Routine ' + (t.count ? t.count + '×' : '') + '</span>';
        if (m === 'variant') return '<span class="b variant">⇄ Variante</span>';
        if (m === 'favorite') return '<span class="b favorite">♥ Favori</span>';
        return '';
      }
      
      function keyBadge(t, cls) {
        if (!t.key || t.key === '--') return '<span class="' + (cls || 'key') + ' none">--</span>';
        var style = t.keyColor ? ' style="background:' + esc(t.keyColor) + '"' : '';
        return '<span class="' + (cls || 'key') + '"' + style + '>' + esc(t.key) + '</span>';
      }
      
      function bpmDiff(t) {
        if (t.bpmDiff == null || !isFinite(t.bpmDiff) || Math.abs(t.bpmDiff) < 0.05) return '';
        var v = Math.round(t.bpmDiff * 10) / 10;
        return '<span class="d ' + (v > 0 ? 'up' : 'down') + '">' + (v > 0 ? '+' : '') + v + '</span>';
      }
      
      function render(s) {
        var root = document.documentElement;
        if (s.app) {
          if (s.app.accent) root.style.setProperty('--accent', s.app.accent);
          if (s.app.accent2) root.style.setProperty('--accent2', s.app.accent2);
        }
        var st = s.status || {};
        var now = s.nowPlaying;
        var nowEl = $('now');
        
        if (now) {
          nowEl.classList.remove('idle');
          $('nowLabel').textContent = st.manualOverride ? 'Sélection manuelle' : 'En cours';
          $('deck').textContent = st.deck && st.deck !== 'AUTO' ? 'Deck ' + st.deck : (st.software === 'rekordbox' ? 'Rekordbox' : 'Serato');
          $('nowTitle').textContent = now.title || 'Morceau inconnu';
          $('nowArtist').textContent = now.artist || '';
          $('nowMeta').innerHTML =
            keyBadge(now, 'pill key') +
            '<span class="pill">' + esc(now.bpmText || '--') + ' <span class="u">BPM</span></span>' +
            (now.genre ? '<span class="pill">' + esc(now.genre) + '</span>' : '') +
            (st.playedCount ? '<span class="pill">' + st.playedCount + ' <span class="u">JOUÉS</span></span>' : '');
        } else {
          nowEl.classList.add('idle');
          $('nowLabel').textContent = st.connected ? 'En attente' : 'Logiciel DJ non détecté';
          $('deck').textContent = '';
          $('nowTitle').textContent = 'Lancez un morceau';
          $('nowArtist').textContent = st.connected
            ? 'Les suggestions apparaîtront ici dès qu\u2019un morceau joue sur une platine.'
            : 'Ouvrez Serato DJ Pro ou Rekordbox sur le Mac pour démarrer.';
          $('nowMeta').innerHTML = '';
        }
        
        var f = s.filters || {};
        var mode = s.mode || 'suggestions';
        $('listTitle').textContent = mode === 'toplay' ? 'Sélec à jouer' : mode === 'favorites' ? 'Favoris' : 'Suggestions';
        $('count').textContent = s.totalCount || 0;
        var chips = [];
        if (f.harmonic) chips.push('<span class="chip">♪ Harmonie</span>');
        if (f.bpm) chips.push('<span class="chip">BPM ±' + (f.bpmTolerance || 0) + '%</span>');
        if (f.favorites) chips.push('<span class="chip fav">♥ Favoris</span>');
        if (f.hidePlayed) chips.push('<span class="chip">Joués masqués</span>');
        if (f.direction === 'previous') chips.push('<span class="chip">← Avant</span>');
        if (f.direction === 'all') chips.push('<span class="chip">⇄ Tout</span>');
        $('chips').innerHTML = chips.join('');
        
        var list = $('list');
        var tracks = s.tracks || [];
        if (st.isLoading && !tracks.length) {
          list.innerHTML = '<div class="empty"><div class="ico">⏳</div><b>Recherche des enchaînements…</b></div>';
        } else if (!now && mode !== 'toplay') {
          list.innerHTML = '<div class="empty"><div class="ico">▶️</div><b>Lancer la lecture</b>Démarrez un morceau sur une platine pour afficher vos enchaînements habituels.</div>';
        } else if (!tracks.length) {
          var msg = mode === 'toplay' ? 'Votre Sélec est vide. Glissez des morceaux dans Recall sur le Mac.'
            : mode === 'favorites' ? 'Aucun combo favori pour ce morceau.'
            : 'Aucun enchaînement connu pour ce morceau avec les filtres actifs.';
          list.innerHTML = '<div class="empty"><div class="ico">🎧</div><b>Rien à afficher</b>' + esc(msg) + '</div>';
        } else {
          var html = '';
          for (var i = 0; i < tracks.length; i++) {
            var t = tracks[i];
            var badges = matchBadge(t);
            if (t.relation) badges += '<span class="b ' + (t.energyBoost ? 'boost' : 'rel') + '">' + esc(t.relation) + '</span>';
            if (t.isFavorite && t.matchType !== 'favorite') badges += '<span class="b heart">♥</span>';
            if (t.played) badges += '<span class="b played">✓ Joué</span>';
            html += '<div class="row' + (i === 0 && mode !== 'toplay' ? ' top' : '') + (t.played ? ' played' : '') + '">' +
              '<div class="idx">' + (i + 1) + '</div>' +
              '<div><div class="t">' + esc(t.title) + '</div><div class="a">' + esc(t.artist) + '</div>' +
              (badges ? '<div class="badges">' + badges + '</div>' : '') + '</div>' +
              '<div class="right">' + keyBadge(t) +
              '<div class="bpm">' + esc(t.bpmText || '--') + '<small>BPM</small>' + bpmDiff(t) + '</div></div>' +
              '</div>';
          }
          list.innerHTML = html;
        }
        if (s.app && s.app.version) $('foot').textContent = 'Recall v' + s.app.version + ' • 100 % local, sans Internet';
      }
      
      function connect() {
        if (es) { es.close(); es = null; }
        setConn('wait', 'Connexion…');
        es = new EventSource('/api/events?pin=' + encodeURIComponent(pin));
        es.onopen = function () { setConn('on', 'En direct'); };
        es.onmessage = function (e) {
          if (e.data === lastJSON) return;
          lastJSON = e.data;
          try { render(JSON.parse(e.data)); } catch (err) {}
          setConn('on', 'En direct');
        };
        es.onerror = function () {
          setConn('off', 'Reconnexion…');
          if (es && es.readyState === EventSource.CLOSED) {
            // Fermé définitivement (ex: PIN refusé ou Recall arrêté) : vérification puis reconnexion
            setTimeout(boot, 2500);
          }
        };
      }
      
      function boot() {
        fetch('/api/state?pin=' + encodeURIComponent(pin), { cache: 'no-store' })
          .then(function (r) {
            if (r.status === 403) { showPin(pin ? 'Code incorrect' : ''); throw new Error('pin'); }
            if (!r.ok) throw new Error('http');
            return r.json();
          })
          .then(function (s) {
            $('pin').classList.add('hidden'); $('app').classList.remove('hidden');
            render(s);
            connect();
          })
          .catch(function (e) {
            if (e.message === 'pin') return;
            setConn('off', 'Recall injoignable');
            setTimeout(boot, 3000);
          });
      }
      
      $('pinBtn').addEventListener('click', function () {
        pin = $('pinInput').value.trim();
        localStorage.setItem('recall_pin', pin);
        boot();
      });
      $('pinInput').addEventListener('keydown', function (e) { if (e.key === 'Enter') $('pinBtn').click(); });
      
      // Garder l'écran allumé sur le téléphone pendant le set
      function requestWakeLock() {
        if (!('wakeLock' in navigator)) return;
        navigator.wakeLock.request('screen').then(function (l) { wakeLock = l; }).catch(function () {});
      }
      document.addEventListener('visibilitychange', function () {
        if (document.visibilityState === 'visible') { requestWakeLock(); boot(); }
      });
      requestWakeLock();
      boot();
    })();
    </script>
    </body>
    </html>
    """#
}
