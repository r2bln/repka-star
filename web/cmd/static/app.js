function showStatus(text, isError) {
  const el = document.getElementById('status');
  el.textContent = text;
  el.className = isError ? 'status error' : 'status ok';
  clearTimeout(showStatus.timer);
  showStatus.timer = setTimeout(() => { el.textContent = ''; el.className = ''; }, 5000);
}

function fieldId(configId, sectionIndex, keyIndex) {
  return `f-${configId}-${sectionIndex}-${keyIndex}`;
}

function renderConfig(config) {
  const article = document.createElement('article');
  article.id = `config-${config.id}`;

  const header = document.createElement('header');
  header.innerHTML = `<strong>${config.name}</strong> <small>${config.path}</small>`;
  article.appendChild(header);

  config.sections.forEach((section, sIdx) => {
    const details = document.createElement('details');
    const summary = document.createElement('summary');
    summary.textContent = `[${section.name}]`;
    details.appendChild(summary);

    section.keys.forEach((kv, kIdx) => {
      const label = document.createElement('label');
      label.textContent = kv.key;
      const input = document.createElement('input');
      input.type = 'text';
      input.id = fieldId(config.id, sIdx, kIdx);
      input.value = kv.value;
      label.appendChild(input);
      details.appendChild(label);
    });

    article.appendChild(details);
  });

  const actions = document.createElement('div');
  actions.className = 'grid';

  const saveBtn = document.createElement('button');
  saveBtn.textContent = 'Сохранить';
  saveBtn.onclick = () => saveConfig(config);
  actions.appendChild(saveBtn);

  const restartBtn = document.createElement('button');
  restartBtn.textContent = `Перезапустить ${config.service}`;
  restartBtn.className = 'secondary';
  restartBtn.onclick = () => restartService(config);
  actions.appendChild(restartBtn);

  article.appendChild(actions);

  const serviceState = document.createElement('p');
  serviceState.className = 'service-state';
  serviceState.id = `service-state-${config.id}`;
  article.appendChild(serviceState);

  return article;
}

function collectSections(config) {
  return config.sections.map((section, sIdx) => ({
    name: section.name,
    keys: section.keys.map((kv, kIdx) => ({
      key: kv.key,
      value: document.getElementById(fieldId(config.id, sIdx, kIdx)).value,
    })),
  }));
}

function replaceConfigArticle(config) {
  const old = document.getElementById(`config-${config.id}`);
  const fresh = renderConfig(config);
  if (old) {
    old.replaceWith(fresh);
  } else {
    document.getElementById('configs').appendChild(fresh);
  }
}

async function saveConfig(config) {
  try {
    const res = await fetch(`/api/configs/${config.id}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ sections: collectSections(config) }),
    });
    if (!res.ok) throw new Error(await res.text());
    const saved = await res.json();
    replaceConfigArticle(saved);
    showStatus(`${config.name}: сохранено и перечитано с диска`, false);
  } catch (err) {
    showStatus(`${config.name}: ошибка сохранения — ${err.message}`, true);
  }
}

async function restartService(config) {
  const stateEl = document.getElementById(`service-state-${config.id}`);
  try {
    const res = await fetch(`/api/restart/${config.id}`, { method: 'POST' });
    if (!res.ok) throw new Error(await res.text());
    const { service, status } = await res.json();
    const active = status === 'active';
    if (stateEl) {
      stateEl.textContent = `${service}: ${status}`;
      stateEl.className = `service-state ${active ? 'ok' : 'error'}`;
    }
    showStatus(`${service}: перезапущен, статус — ${status}`, !active);
  } catch (err) {
    showStatus(`${config.service}: ошибка перезапуска — ${err.message}`, true);
  }
}

async function loadConfigs() {
  const container = document.getElementById('configs');
  try {
    const res = await fetch('/api/configs');
    if (!res.ok) throw new Error(await res.text());
    const configs = await res.json();
    container.innerHTML = '';
    configs.forEach(config => container.appendChild(renderConfig(config)));
  } catch (err) {
    container.textContent = `Не удалось загрузить конфиги: ${err.message}`;
  }
}

loadConfigs();
