/* Widget: activity-feed */

WIDGET_REGISTRY['activity-feed'] = {
  title: 'Activity Feed',
  icon: '\u26A1',
  defaultSize: { w: 6, h: 6 },
  minW: 4, minH: 3,

  init(contentEl) {
    this._contentEl = contentEl;
    this._sources = new Set(
      JSON.parse(localStorage.getItem('activity-feed-sources') || '["git","ado","sentry","github"]')
    );
    contentEl.innerHTML = `
      <div class="af-filter-bar" id="af-filter-bar"></div>
      <div class="af-list" id="af-list">${skeletonRows(6, 'list')}</div>`;
    this._renderFilters(contentEl);
    this._interval = setInterval(() => this._load(contentEl), 60 * 1000);
    this._load(contentEl);
  },

  _renderFilters(contentEl) {
    const bar = contentEl.querySelector('#af-filter-bar');
    if (!bar) return;
    const SOURCES = { git: 'Git', ado: 'ADO', sentry: 'Sentry', github: 'GitHub' };
    bar.innerHTML = Object.entries(SOURCES).map(([key, label]) =>
      `<button class="ado-filter-chip af-chip${this._sources.has(key) ? ' active' : ''}" data-src="${key}">${label}</button>`
    ).join('');
    bar.querySelectorAll('.af-chip').forEach(btn => {
      btn.addEventListener('click', () => {
        const src = btn.dataset.src;
        if (this._sources.has(src)) {
          if (this._sources.size > 1) this._sources.delete(src);
        } else {
          this._sources.add(src);
        }
        localStorage.setItem('activity-feed-sources', JSON.stringify([...this._sources]));
        this._renderFilters(contentEl);
        this._renderEvents(contentEl);
      });
    });
  },

  async _load(contentEl) {
    try {
      const res = await fetch('/api/activity');
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      this._events = await res.json();
      this._renderEvents(contentEl);
    } catch (err) {
      const list = contentEl.querySelector('#af-list');
      if (list) list.innerHTML = `<span class="panel-loading">Error: ${esc(err.message)}</span>`;
    }
  },

  _renderEvents(contentEl) {
    const list = contentEl.querySelector('#af-list');
    if (!list || !this._events) return;

    const visible = this._events.filter(e => this._sources.has(e.source));

    if (!visible.length) {
      list.innerHTML = '<span class="panel-loading">No recent activity</span>';
      return;
    }

    list.innerHTML = visible.map(e => {
      const cfg = AF_SOURCES[e.source] || AF_SOURCES.git;
      const levelClass = e.level === 'error' ? 'af-level-error' :
                         e.level === 'warning' ? 'af-level-warning' :
                         e.level === 'success' ? 'af-level-success' : '';
      const repoTag = e.repo ? `<span class="af-repo">${esc(e.repo)}</span>` : '';
      const inner = `
        <span class="af-source-badge" style="background:${cfg.bg};color:${cfg.color}">${cfg.label}</span>
        <span class="af-time">${_afTimeAgo(e.timestamp)}</span>
        <span class="af-text ${levelClass}">${esc(e.text)}${repoTag}</span>`;
      return e.url
        ? `<a class="af-row" href="${esc(e.url)}" target="_blank" rel="noopener">${inner}</a>`
        : `<div class="af-row">${inner}</div>`;
    }).join('');
  },

  refresh(_, contentEl) { this._load(contentEl || this._contentEl); },
  destroy() { if (this._interval) clearInterval(this._interval); },
};

const AF_SOURCES = {
  git:    { label: 'Git',    bg: 'rgba(166,173,200,0.15)', color: 'var(--overlay2)' },
  ado:    { label: 'ADO',   bg: 'rgba(137,180,250,0.15)', color: 'var(--blue)'     },
  sentry: { label: 'Sentry', bg: 'rgba(243,139,168,0.15)', color: 'var(--red)'      },
  github: { label: 'GitHub', bg: 'rgba(166,227,161,0.15)', color: 'var(--green)'    },
};

function _afTimeAgo(iso) {
  const s = Math.floor((Date.now() - new Date(iso)) / 1000);
  if (s < 60)   return `${s}s ago`;
  if (s < 3600) return `${Math.floor(s / 60)}m ago`;
  if (s < 86400) return `${Math.floor(s / 3600)}h ago`;
  return `${Math.floor(s / 86400)}d ago`;
}
