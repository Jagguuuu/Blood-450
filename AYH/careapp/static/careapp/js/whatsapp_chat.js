/**
 * Blood450 WhatsApp live chat — WebSocket + REST.
 * Requires window.WA_CHAT_CONFIG from template.
 */
(function () {
  var cfg = window.WA_CHAT_CONFIG || {};
  if (!cfg.enabled) return;

  var isAdmin = !!cfg.isAdmin;
  var apiBase = (cfg.apiBase || '/api/whatsapp/').replace(/\/?$/, '/');
  var wsPath = isAdmin ? '/ws/whatsapp/admin/' : '/ws/whatsapp/donor/';
  var wsUrl = (cfg.wsScheme || (location.protocol === 'https:' ? 'wss:' : 'ws:')) + '//' + location.host + wsPath;

  var fab = document.getElementById('waFab');
  var fabBadge = document.getElementById('waFabBadge');
  var overlay = document.getElementById('waModalOverlay');
  var closeBtn = document.getElementById('waModalClose');
  var sidebar = document.getElementById('waSidebar');
  var messagesEl = document.getElementById('waMessages');
  var composeInput = document.getElementById('waComposeInput');
  var sendBtn = document.getElementById('waSendBtn');
  var chatTitle = document.getElementById('waChatTitle');
  var modalBody = document.getElementById('waModalBody');

  var conversations = [];
  var activeConvId = null;
  var socket = null;
  var pollTimer = null;

  function csrf() {
    var m = document.cookie.match(/csrftoken=([^;]+)/);
    return m ? m[1] : '';
  }

  function fetchJson(url, opts) {
    opts = opts || {};
    opts.credentials = 'same-origin';
    opts.headers = opts.headers || {};
    opts.headers['X-Requested-With'] = 'XMLHttpRequest';
    if (opts.method && opts.method !== 'GET') {
      opts.headers['X-CSRFToken'] = csrf();
      opts.headers['Content-Type'] = 'application/json';
    }
    return fetch(url, opts).then(function (r) {
      return r.json().then(function (data) {
        if (!r.ok) {
          var err =
            (data && (data.error || data.detail)) ||
            r.statusText ||
            'Request failed';
          if (typeof err === 'object') err = JSON.stringify(err);
          throw new Error(err);
        }
        return data;
      });
    });
  }

  function updateBadge(count) {
    if (!fabBadge) return;
    fabBadge.textContent = count;
    fabBadge.style.display = count > 0 ? 'flex' : 'none';
    if (fab) fab.classList.toggle('pulse', count > 0);
  }

  function loadUnread() {
    fetchJson(apiBase + 'unread/')
      .then(function (d) { updateBadge(d.unread || 0); })
      .catch(function () {});
  }

  function renderConversations() {
    if (!sidebar || !isAdmin) return;
    sidebar.innerHTML = '';
    conversations.forEach(function (c) {
      var el = document.createElement('div');
      el.className = 'wa-sidebar-item' + (c.id === activeConvId ? ' active' : '');
      el.dataset.id = c.id;
      el.innerHTML =
        '<strong>' + escapeHtml(c.donor_name || c.display_name || c.phone) + '</strong>' +
        '<small>' + escapeHtml(c.last_message_preview || '') + '</small>' +
        (c.unread_admin_count > 0 ? ' <span style="color:#25d366">(' + c.unread_admin_count + ')</span>' : '');
      el.onclick = function () { openConversation(c.id); };
      sidebar.appendChild(el);
    });
  }

  function escapeHtml(s) {
    var d = document.createElement('div');
    d.textContent = s || '';
    return d.innerHTML;
  }

  function renderMessages(msgs) {
    if (!messagesEl) return;
    messagesEl.innerHTML = '';
    msgs.forEach(function (m) {
      var div = document.createElement('div');
      var inbound = m.direction === 'inbound';
      div.className = 'wa-bubble ' + (inbound ? 'inbound' : 'outbound');
      var status = m.status ? ' · ' + m.status : '';
      div.innerHTML =
        escapeHtml(m.body) +
        '<div class="meta">' + (m.created_at || '').replace('T', ' ').slice(0, 16) + status + '</div>';
      messagesEl.appendChild(div);
    });
    messagesEl.scrollTop = messagesEl.scrollHeight;
  }

  function openConversation(id) {
    activeConvId = id;
    if (modalBody && window.innerWidth < 768) {
      modalBody.classList.remove('show-list');
    }
    renderConversations();
    fetchJson(apiBase + 'conversations/' + id + '/messages/?page_size=80')
      .then(function (data) {
        if (chatTitle) {
          chatTitle.textContent = (data.conversation && (data.conversation.donor_name || data.conversation.display_name)) || 'Chat';
        }
        renderMessages(data.messages || []);
        loadUnread();
      })
      .catch(function () {
        if (messagesEl) messagesEl.innerHTML = '<p>Failed to load messages.</p>';
      });
    if (socket && socket.readyState === 1) {
      socket.send(JSON.stringify({ action: 'subscribe', conversation_id: id }));
    }
  }

  function loadConversations() {
    return fetchJson(apiBase + 'conversations/')
      .then(function (list) {
        conversations = list || [];
        renderConversations();
        if (isAdmin && conversations.length && !activeConvId) {
          openConversation(conversations[0].id);
        } else if (!isAdmin && conversations.length) {
          openConversation(conversations[0].id);
        }
      });
  }

  function sendMessage() {
    if (!activeConvId || !composeInput) return;
    var body = composeInput.value.trim();
    if (!body) return;
    composeInput.value = '';
    fetchJson(apiBase + 'conversations/' + activeConvId + '/send/', {
      method: 'POST',
      body: JSON.stringify({ body: body }),
    })
      .then(function () { openConversation(activeConvId); })
      .catch(function (err) {
        alert(err.message || 'Send failed. Check WhatsApp API configuration.');
        openConversation(activeConvId);
      });
  }

  function connectWs() {
    try {
      socket = new WebSocket(wsUrl);
    } catch (e) {
      startPollFallback();
      return;
    }
    socket.onopen = function () {
      if (activeConvId) {
        socket.send(JSON.stringify({ action: 'subscribe', conversation_id: activeConvId }));
      }
    };
    socket.onmessage = function (ev) {
      try {
        var data = JSON.parse(ev.data);
        if (data.type === 'chat_message' && data.conversation_id === activeConvId) {
          openConversation(activeConvId);
        }
        if (data.type === 'chat_message' || data.type === 'blood_response') {
          loadUnread();
          if (isAdmin) loadConversations();
        }
      } catch (e) {}
    };
    socket.onclose = function () {
      setTimeout(connectWs, 4000);
    };
    socket.onerror = function () {
      startPollFallback();
    };
  }

  function startPollFallback() {
    if (pollTimer) return;
    pollTimer = setInterval(function () {
      if (overlay && overlay.classList.contains('show') && activeConvId) {
        openConversation(activeConvId);
      }
      loadUnread();
    }, 8000);
  }

  if (fab) {
    fab.addEventListener('click', function () {
      overlay.classList.add('show');
      loadConversations().then(function () {
        if (!isAdmin && conversations[0]) openConversation(conversations[0].id);
      });
      if (modalBody && window.innerWidth < 768 && isAdmin) {
        modalBody.classList.add('show-list');
      }
    });
  }
  if (closeBtn) {
    closeBtn.addEventListener('click', function () {
      overlay.classList.remove('show');
    });
  }
  if (overlay) {
    overlay.addEventListener('click', function (e) {
      if (e.target === overlay) overlay.classList.remove('show');
    });
  }
  if (sendBtn) sendBtn.addEventListener('click', sendMessage);
  if (composeInput) {
    composeInput.addEventListener('keydown', function (e) {
      if (e.key === 'Enter' && !e.shiftKey) {
        e.preventDefault();
        sendMessage();
      }
    });
  }

  loadUnread();
  connectWs();
  setInterval(loadUnread, 15000);
})();
