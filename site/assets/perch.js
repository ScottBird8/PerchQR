// Shared markup + behavior reused across every PerchQR page. This is the
// multi-tenant descendant of the single-tenant "Stratum" helper object from
// C:\Users\scott\Scotts QR\site\assets\site.js — same UI behaviors (video
// state machines, gallery, Matterport toggle), but every piece of agent
// identity (name, phone, brokerage, branding) is now a parameter instead of
// a hardcoded constant, since one deploy serves every agent.
//
// IMPORTANT: every link and asset path in this file and every page that uses
// it must be ABSOLUTE ("/assets/...", "/" + agent.slug + "/listing?id=...").
// Pages are reached via Netlify rewrites that change which file is served
// without changing the browser's URL bar (e.g. /scott-bird/listing still
// serves listing.html), so a relative path resolves against whatever path
// segment depth the visitor is actually on, not the file's real location.
const Perch = (function () {
  const TYPE_LABEL = { residential: 'Residential', land: 'Land', business: 'Business Opportunity' };

  function esc(str) {
    if (str === null || str === undefined) return '';
    return String(str)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#39;');
  }

  // agent.phone is stored as digits only ("4355907106"); this is purely for
  // display — tel:/sms: hrefs use the raw digit string directly.
  function formatPhone(digits) {
    const d = String(digits || '').replace(/\D/g, '');
    if (d.length !== 10) return digits || '';
    return `(${d.slice(0, 3)}) ${d.slice(3, 6)}-${d.slice(6)}`;
  }

  const GOOGLE_SVG = `<svg width="18" height="18" viewBox="0 0 18 18" xmlns="http://www.w3.org/2000/svg">
<path fill="#4285F4" d="M17.64 9.2045c0-.6381-.0573-1.2518-.1636-1.8409H9v3.4814h4.8436c-.2086 1.125-.8427 2.0782-1.7959 2.7164v2.2581h2.9087c1.7018-1.5668 2.6836-3.8741 2.6836-6.615z"/>
<path fill="#34A853" d="M9 18c2.43 0 4.4673-.8055 5.9564-2.1805l-2.9087-2.2581c-.8059.54-1.8368.859-3.0477.859-2.3441 0-4.3282-1.5831-5.0359-3.7104H.9573v2.3318C2.4382 15.9832 5.4818 18 9 18z"/>
<path fill="#FBBC05" d="M3.9641 10.71c-.18-.54-.2822-1.1168-.2822-1.71s.1022-1.17.2822-1.71V4.9582H.9573C.3477 6.1732 0 7.5477 0 9s.3477 2.8268.9573 4.0418L3.9641 10.71z"/>
<path fill="#EA4335" d="M9 3.5795c1.3214 0 2.5077.4541 3.4405 1.346l2.5813-2.5814C13.4632.8918 11.4259 0 9 0 5.4818 0 2.4382 2.0168.9573 4.9582L3.9641 7.29C4.6718 5.1627 6.6559 3.5795 9 3.5795z"/>
</svg>`;

  const FACEBOOK_SVG = `<svg width="18" height="18" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
<path fill="#1877F2" d="M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.99 4.388 10.954 10.125 11.854v-8.385H7.078v-3.47h3.047V9.43c0-3.007 1.792-4.669 4.533-4.669 1.312 0 2.686.235 2.686.235v2.953H15.83c-1.491 0-1.956.925-1.956 1.874v2.25h3.328l-.532 3.47h-2.796v8.385C19.612 23.027 24 18.062 24 12.073z"/>
</svg>`;

  // agent: { slug, display_name, brokerage_name, phone, email, logo_url,
  //          headshot_url, license_number, address_line, google_url, facebook_url }
  function renderHeader(agent) {
    const home = `/${agent.slug}`;
    const logo = agent.logo_url
      ? `<img class="logo" src="${esc(agent.logo_url)}" alt="${esc(agent.display_name)}">`
      : '';
    return `<header class="site-header">
  <div class="header-inner">
    <div class="header-left">
      <button class="hamburger-btn" id="hamburgerBtn" type="button" aria-label="Menu" aria-expanded="false">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M3 6h18M3 12h18M3 18h18"/></svg>
      </button>
      <a href="${home}" class="brand">
        ${logo}
        <div class="brand-text">
          <span class="agent-name">${esc(agent.display_name)}</span>
          ${agent.brokerage_name ? `<span class="agent-tag">${esc(agent.brokerage_name)}</span>` : ''}
        </div>
      </a>
      <div class="hamburger-dropdown" id="hamburgerDropdown">
        <a href="${home}">Home</a>
        <a href="${home}#contact">Contact</a>
      </div>
    </div>
    <nav class="site-nav">
      <a class="nav-link" href="${home}#listings">Listings</a>
      <a class="nav-link" href="${home}#contact">Contact</a>
      ${agent.phone ? `<a class="nav-cta" href="tel:${esc(agent.phone)}">${esc(formatPhone(agent.phone))}</a>` : ''}
    </nav>
  </div>
</header>`;
  }

  function wireHeader() {
    const btn = document.getElementById('hamburgerBtn');
    const menu = document.getElementById('hamburgerDropdown');
    if (!btn || !menu) return;
    btn.addEventListener('click', (e) => {
      e.stopPropagation();
      const open = menu.classList.toggle('open');
      btn.setAttribute('aria-expanded', open ? 'true' : 'false');
    });
    document.addEventListener('click', (e) => {
      if (!menu.contains(e.target) && e.target !== btn) {
        menu.classList.remove('open');
        btn.setAttribute('aria-expanded', 'false');
      }
    });
    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape') { menu.classList.remove('open'); btn.setAttribute('aria-expanded', 'false'); }
    });
  }

  function renderFooter(agent) {
    const company = esc(agent.brokerage_name || agent.display_name);
    return `<footer class="site-footer">
  <span>&copy; ${new Date().getFullYear()} ${company}. Information deemed reliable but not guaranteed.</span>
  ${agent.license_number ? `<span>License #${esc(agent.license_number)}</span>` : '<span></span>'}
</footer>`;
  }

  function renderContact(agent) {
    const socialButtons = [];
    if (agent.google_url) socialButtons.push(`<a class="social-btn" href="${esc(agent.google_url)}" target="_blank" rel="noopener" aria-label="Connect with Google">${GOOGLE_SVG}<span>Connect with Google</span></a>`);
    if (agent.facebook_url) socialButtons.push(`<a class="social-btn" href="${esc(agent.facebook_url)}" target="_blank" rel="noopener" aria-label="Connect with Facebook">${FACEBOOK_SVG}<span>Connect with Facebook</span></a>`);

    const headshot = agent.headshot_url
      ? `<img src="${esc(agent.headshot_url)}" alt="${esc(agent.display_name)}">`
      : '';

    return `<section class="contact-section" id="contact">
    <div class="contact-copy">
      <h2>Let's talk about Real Estate!</h2>
      <p>Whatever the property, whatever the goal, I'll bring the experience, insight, and numbers you need to make a confident decision&mdash;on your terms.</p>
      <div class="hero-actions">
        ${agent.phone ? `<a href="tel:${esc(agent.phone)}" class="btn btn-primary">Call ${esc(formatPhone(agent.phone))}</a>` : ''}
        ${agent.phone ? `<a href="sms:${esc(agent.phone)}" class="btn btn-ghost">Text ${esc(agent.display_name.split(' ')[0])}</a>` : ''}
        ${agent.email ? `<a href="mailto:${esc(agent.email)}" class="btn btn-ghost">Email ${esc(agent.display_name.split(' ')[0])}</a>` : ''}
      </div>
    </div>
    <div class="contact-card">
      ${headshot}
      <div>
        <h3>${esc(agent.display_name)}</h3>
        ${agent.brokerage_name ? `<div class="role">${esc(agent.brokerage_name)}</div>` : ''}
        ${agent.address_line ? `<div class="contact-line">${esc(agent.address_line)}</div>` : ''}
        ${agent.phone ? `<div class="contact-line"><a href="tel:${esc(agent.phone)}">${esc(formatPhone(agent.phone))}</a></div>` : ''}
        ${agent.email ? `<div class="contact-line"><a href="mailto:${esc(agent.email)}">${esc(agent.email)}</a></div>` : ''}
        ${socialButtons.length ? `<div class="social-row">${socialButtons.join('')}</div>` : ''}
      </div>
    </div>
  </section>`;
  }

  // Homepage welcome video: click-to-play. Shrinks to a fixed top-right box
  // 5s after starting, or immediately on click-to-skip/pause. Only called
  // when the agent has actually configured a home_video_url.
  function initHomeVideo() {
    const wrap = document.getElementById('heroVideoWrap');
    const video = document.getElementById('welcomeVideo');
    const overlay = document.getElementById('playOverlay');
    if (!wrap || !video) return;
    let minimizeTimer = null;

    function setPaused(isPaused) { wrap.classList.toggle('is-paused', isPaused); }
    function floatMinimized() { wrap.classList.add('small', 'floating'); clearTimeout(minimizeTimer); }
    function expand() { wrap.classList.remove('small', 'floating'); }
    function playFull() {
      expand();
      overlay.classList.add('hidden');
      setPaused(false);
      video.currentTime = 0;
      const p = video.play();
      if (p && p.catch) p.catch(() => { overlay.classList.remove('hidden'); setPaused(true); });
      clearTimeout(minimizeTimer);
      minimizeTimer = setTimeout(floatMinimized, 5000);
    }

    video.addEventListener('playing', () => { overlay.classList.add('hidden'); setPaused(false); });
    video.addEventListener('pause', () => setPaused(true));
    video.addEventListener('ended', () => { floatMinimized(); setPaused(true); overlay.classList.remove('hidden'); });

    wrap.addEventListener('click', () => {
      if (wrap.classList.contains('small')) { playFull(); return; }
      if (video.paused) { playFull(); return; }
      clearTimeout(minimizeTimer);
      video.pause();
      floatMinimized();
    });
  }

  // Per-property "message from the agent" video: autoplays in full only the
  // first time a given browser visits this specific property (localStorage
  // flag keyed by property id), otherwise starts already docked small.
  // Floats (position:fixed) for its entire life.
  function initPropertyVideo(propertyId) {
    const KEY = 'perch_video_seen_' + propertyId;
    const overlay = document.getElementById('heroVideoOverlay');
    const video = document.getElementById('propVideo');
    const toggleBtn = document.getElementById('videoToggleBtn');
    if (!overlay || !video) return;
    let minimizeTimer = null;

    const baseRect = overlay.getBoundingClientRect();
    const headerEl = document.querySelector('.site-header');
    const minTop = (headerEl ? headerEl.getBoundingClientRect().bottom : 60) + 10;

    function setPaused(isPaused) { overlay.classList.toggle('is-paused', isPaused); }

    function clearInlineRect() {
      overlay.style.top = ''; overlay.style.left = ''; overlay.style.width = ''; overlay.style.height = '';
    }

    function floatMinimized() {
      clearInlineRect();
      overlay.classList.add('small', 'floating');
      clearTimeout(minimizeTimer);
    }

    function floatFull() {
      overlay.classList.remove('small');
      overlay.classList.add('floating');
      const margin = 8;
      const maxLeft = Math.max(window.innerWidth - baseRect.width - margin, margin);
      overlay.style.left = Math.min(Math.max(baseRect.left, margin), maxLeft) + 'px';
      overlay.style.top = Math.max(baseRect.top, minTop) + 'px';
      overlay.style.width = baseRect.width + 'px';
      overlay.style.height = baseRect.height + 'px';
    }

    video.addEventListener('loadedmetadata', () => {
      overlay.classList.toggle('portrait', video.videoHeight > video.videoWidth);
    });

    function playFull() {
      floatFull();
      overlay.classList.remove('needs-tap');
      setPaused(false);
      video.currentTime = 0;
      const p = video.play();
      if (p && p.catch) p.catch(() => { overlay.classList.add('needs-tap'); setPaused(true); });
      clearTimeout(minimizeTimer);
      minimizeTimer = setTimeout(() => { floatMinimized(); }, 5000);
    }

    video.addEventListener('playing', () => { overlay.classList.remove('needs-tap'); setPaused(false); });
    video.addEventListener('pause', () => setPaused(true));
    video.addEventListener('ended', () => { floatMinimized(); setPaused(true); });

    overlay.addEventListener('click', () => {
      if (overlay.classList.contains('needs-tap')) { playFull(); return; }
      if (overlay.classList.contains('small')) { playFull(); return; }
      clearTimeout(minimizeTimer);
      video.pause();
      floatMinimized();
    });

    if (toggleBtn) {
      toggleBtn.addEventListener('click', (e) => {
        e.stopPropagation();
        if (video.paused) { video.play(); } else { video.pause(); }
      });
    }

    let seen = false;
    try { seen = !!localStorage.getItem(KEY); } catch (e) {}
    if (!seen) {
      try { localStorage.setItem(KEY, '1'); } catch (e) {}
      playFull();
    } else {
      floatMinimized();
      setPaused(true);
    }
  }

  function initMatterport() {
    const card = document.getElementById('matterportCard');
    const toggle = document.getElementById('matterportToggle');
    if (!card || !toggle) return;
    const iconExpand = document.getElementById('matterportIconExpand');
    const iconCollapse = document.getElementById('matterportIconCollapse');
    const label = document.getElementById('matterportToggleLabel');
    function setMaximized(on) {
      card.classList.toggle('maximized', on);
      iconExpand.style.display = on ? 'none' : '';
      iconCollapse.style.display = on ? '' : 'none';
      label.textContent = on ? 'Minimize' : 'Full screen';
      document.body.style.overflow = on ? 'hidden' : '';
    }
    toggle.addEventListener('click', () => setMaximized(!card.classList.contains('maximized')));
    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape' && card.classList.contains('maximized')) setMaximized(false);
    });
  }

  function initGallery(photos) {
    const img = document.getElementById('pdHeroImg');
    const counter = document.getElementById('pdHeroCounter');
    const strip = document.getElementById('pdGalleryStrip');
    if (!img || photos.length < 2) return;
    let idx = 0;
    function show(i) {
      idx = (i + photos.length) % photos.length;
      img.src = photos[idx];
      if (counter) counter.textContent = (idx + 1) + ' / ' + photos.length;
      if (strip) strip.querySelectorAll('.pd-gallery-thumb').forEach((el, i2) => el.classList.toggle('active', i2 === idx));
    }
    const prevBtn = document.getElementById('pdHeroPrev');
    const nextBtn = document.getElementById('pdHeroNext');
    if (prevBtn) prevBtn.addEventListener('click', () => show(idx - 1));
    if (nextBtn) nextBtn.addEventListener('click', () => show(idx + 1));
    if (strip) strip.querySelectorAll('.pd-gallery-thumb').forEach(btn => {
      btn.addEventListener('click', () => show(parseInt(btn.dataset.index, 10)));
    });

    const heroWrap = document.querySelector('.pd-hero');
    if (heroWrap) {
      let touchStartX = null, touchStartY = null;
      heroWrap.addEventListener('touchstart', (e) => {
        if (e.target.closest('.hero-video-overlay')) { touchStartX = null; return; }
        touchStartX = e.touches[0].clientX;
        touchStartY = e.touches[0].clientY;
      }, { passive: true });
      heroWrap.addEventListener('touchend', (e) => {
        if (touchStartX === null) return;
        const dx = e.changedTouches[0].clientX - touchStartX;
        const dy = e.changedTouches[0].clientY - touchStartY;
        touchStartX = null;
        if (Math.abs(dx) < 40 || Math.abs(dx) < Math.abs(dy)) return;
        show(dx < 0 ? idx + 1 : idx - 1);
      });
    }
  }

  function renderFacts(facts) {
    return (facts || []).map(([k, v]) => `<div class="fact"><div class="k">${esc(k)}</div><div class="v">${esc(v)}</div></div>`).join('\n');
  }

  function renderRooms(rooms) {
    if (!rooms || !rooms.length) return '';
    const chips = rooms.map(r => `<span class="room-chip">${esc(r)}</span>`).join('\n');
    return `<div class="pd-section">
      <h3>Room list</h3>
      <div class="room-list">${chips}</div>
    </div>`;
  }

  function renderOtherListings(agent, properties, excludeId) {
    const items = properties
      .filter(p => p.id !== excludeId && p.status !== 'Sold')
      .map(p => `<a class="ol-card" href="/${agent.slug}/listing?id=${encodeURIComponent(p.id)}">
          <div class="ol-thumb"><img src="${esc(p.hero_photo_url || '')}" alt="${esc(p.full_addr)}"></div>
          <div class="ol-body">
            <div class="ol-addr">${esc(p.addr)}</div>
            <div class="ol-price">${esc(p.price)}</div>
          </div>
        </a>`).join('');
    if (!items) return '';
    return `<div class="other-listings">
      <h3>Other listings</h3>
      <div class="ol-row">${items}</div>
    </div>`;
  }

  function renderTestimonialCard(t) {
    return `<div class="t-card">
      <div class="quote">&ldquo;${esc(t.quote)}&rdquo;</div>
      <div class="who">&mdash; ${esc(t.client_name)}</div>
    </div>`;
  }

  // Records a QR scan. Called by q.html (the /q/<id> redirector) right
  // before it forwards the visitor to the code's stored destination URL —
  // unlike the single-tenant site, individual pages don't need to check for
  // a "?qr=" query param themselves, since the redirector already logged the
  // scan upstream of a clean destination URL.
  async function recordQrScan(agentId, qrCodeId, coords) {
    const row = { agent_id: agentId, qr_code_id: qrCodeId };
    if (coords) { row.lat = coords.lat; row.lng = coords.lng; }
    try { await sb.from('qr_scans').insert(row); } catch (e) { console.error(e); }
  }

  return {
    esc, TYPE_LABEL, formatPhone,
    renderHeader, wireHeader, renderFooter, renderContact,
    initHomeVideo, initPropertyVideo, initMatterport, initGallery,
    renderFacts, renderRooms, renderOtherListings, renderTestimonialCard,
    recordQrScan,
  };
})();
