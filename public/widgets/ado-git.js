/* Widget: ado-git — ADO source control activity + pull requests */

function _adoTimeAgo(iso) {
  if (!iso) return '';
  const s = Math.floor((Date.now() - new Date(iso)) / 1000);
  if (s < 60)    return `${s}s ago`;
  if (s < 3600)  return `${Math.floor(s / 60)}m ago`;
  if (s < 86400) return `${Math.floor(s / 3600)}h ago`;
  return `${Math.floor(s / 86400)}d ago`;
}

WIDGET_REGISTRY['ado-git'] = {
  title: 'ADO Source Control',
  icon: '\uD83D\uDD00',
  settingsKey: 'ado',
  defaultSize: { w: 4, h: 6 },
  minW: 3,
  minH: 3,

  init(contentEl, socket, config) {
    contentEl.innerHTML = `<div class="panel-body" id="widget-ado-git-content">${skeletonRows(5, 'list')}</div>`;
    this._cachedActivity = [];
    this._cachedPrs = [];
    this._interval = setInterval(() => this._load(contentEl), 60000);
    this._load(contentEl);
  },

  async _load(contentEl) {
    const el = contentEl.querySelector('#widget-ado-git-content');
    if (!el) return;
    try {
      const statusRes = await fetch('/api/ado/status');
      const { configured } = await statusRes.json();
      if (!configured) {
        el.innerHTML = `<div class="ado-setup">
          <p>ADO integration requires configuration.</p>
          <p>Set <code>ado</code> in <code>dashboard.config.json</code> and <code>ADO_PAT</code> in your environment.</p>
        </div>`;
        return;
      }
      el.innerHTML = skeletonRows(4, 'list');
      const [activityRes, prsRes] = await Promise.all([
        fetch('/api/ado/repo-activity'),
        fetch('/api/ado/prs'),
      ]);
      this._cachedActivity = activityRes.ok ? await activityRes.json() : [];
      this._cachedPrs      = prsRes.ok      ? await prsRes.json()      : [];
      this._render(contentEl);
    } catch (err) {
      if (el) el.innerHTML = `<span class="panel-loading">Error: ${esc(err.message)}</span>`;
    }
  },

  _render(contentEl) {
    const el = contentEl.querySelector('#widget-ado-git-content');
    if (!el) return;
    const activity = this._cachedActivity;
    const prs = this._cachedPrs;
    const DASH = window.DASH_CONFIG || {};
    let html = '';

    // Active PRs
    html += `<div class="section-title" style="margin-top:0">Open PRs</div>`;
    if (!prs.length) {
      html += `<div class="github-empty">No active PRs</div>`;
    } else {
      html += `<div class="ado-pr-list">`;
      for (const pr of prs) {
        const meta = [pr.createdBy, pr.updatedAt ? `updated ${_adoTimeAgo(pr.updatedAt)}` : ''].filter(Boolean).join(' · ');
        html += `<div class="ado-pr-item">
          <span class="ado-pr-repo">${esc(pr.repo)}</span>
          <span class="ado-pr-title"><a href="${esc(pr.url)}" target="_blank">${esc(pr.title)}</a></span>
          <span class="ado-pr-meta">${esc(meta)}</span>
        </div>`;
      }
      html += `</div>`;
    }

    // Recent Activity
    if (activity.length) {
      html += `<div class="section-title">Recent Activity</div>`;
      html += `<div class="github-activity-list">`;
      for (const r of activity) {
        const when = r.pushedAt ? `Last push ${_adoTimeAgo(r.pushedAt)}` : 'No push data';
        html += `<div class="github-activity-item">
          <span class="github-activity-repo">${esc(r.repo)}</span>
          <span class="github-activity-branch">${esc(r.defaultBranch || 'main')}</span>
          <span class="github-activity-time">${esc(when)}</span>
        </div>`;
      }
      html += `</div>`;
    }

    el.innerHTML = html;
  },

  refresh() {
    const contentEl = document.querySelector('[gs-id="ado-git"] .widget-body');
    if (contentEl) this._load(contentEl);
  },

  destroy() {
    if (this._interval) clearInterval(this._interval);
  },
};
