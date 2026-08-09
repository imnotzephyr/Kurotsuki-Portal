document.addEventListener('contextmenu', event => event.preventDefault());

function ahkButtonClick(ele) {
  ahk.ButtonClick.Func(ele);
}

function ahkSave(ele) {
  ahk.Save.Func(ele);
}

function onSaveClick() {
  const get = (id) => { const el = document.getElementById(id); return el ? el.value : ''; };
  const getBool = (id) => { const el = document.getElementById(id); return el ? +el.checked : 0; };
  const cfg = {
    discordID:             get('discordID'),
    MoveSpeed:             get('MoveSpeed'),
    BotToken:              get('BotToken'),
    MainChannelID:         get('MainChannelID'),
    listenID:              get('listenID'),
    NightChannelID:        get('NightChannelID'),
    StingerChannelID:      get('StingerChannelID'),
    AccountMode:           get('AccountMode'),
    VIPServerLink:         get('VIPServerLink'),
    PassiveMode:           get('PassiveMode'),
    MainCount:             get('MainCount'),
    NightTimeout:          get('NightTimeout'),
    AntiAFKInterval:       get('AntiAFKInterval'),
    PassiveLabel:          get('PassiveLabel'),
    PassiveRes:            get('PassiveRes'),
    GitHubRepo:            get('GitHubRepo'),
    GitHubPAT:             get('GitHubPAT'),
    AutoUpdate:            getBool('AutoUpdate'),
    InstanceTag:           get('InstanceTag'),
    MainSoloHunt:          getBool('MainSoloHunt'),
  };

  ahkSave(JSON.stringify(cfg));
}

function applySettings(a) {
  const s = a.data
  document.getElementById('discordID').value = s.discordID;
  document.getElementById('MoveSpeed').value   = s.MoveSpeed;
  document.getElementById('BotToken').value         = s.BotToken || '';
  document.getElementById('MainChannelID').value    = s.MainChannelID || '';
  document.getElementById('listenID').value         = s.listenID || '';
  document.getElementById('NightChannelID').value   = s.NightChannelID || '';
  document.getElementById('StingerChannelID').value = s.StingerChannelID || '';
  document.getElementById('VIPServerLink').value    = s.VIPServerLink || '';
  document.getElementById('PassiveLabel').value     = s.PassiveLabel || '';
  document.getElementById('PassiveRes').value       = s.PassiveRes || '1280x720';
  if (s.AccountMode)   document.getElementById('AccountMode').value   = s.AccountMode;
  if (s.PassiveMode)   document.getElementById('PassiveMode').value   = s.PassiveMode;
  document.getElementById('GitHubRepo').value       = s.GitHubRepo || 'imnotzephyr/Kurotsuki-Portal';
  document.getElementById('GitHubPAT').value        = s.GitHubPAT || '';
  document.getElementById('AutoUpdate').checked     = s.AutoUpdate === undefined ? true : !!+s.AutoUpdate;
  document.getElementById('InstanceTag').value        = s.InstanceTag || '';
  document.getElementById('MainSoloHunt').checked     = s.MainSoloHunt === undefined ? true : !!+s.MainSoloHunt;
  if (s.MainCount)       document.getElementById('MainCount').value       = s.MainCount;
  if (s.NightTimeout)    document.getElementById('NightTimeout').value    = s.NightTimeout;
  if (s.AntiAFKInterval) document.getElementById('AntiAFKInterval').value = s.AntiAFKInterval;
}

function switchTab(tabId) {
  document.querySelectorAll('.tab').forEach(tab => tab.classList.remove('active'));
  document.getElementById(tabId).classList.add('active');
}

document.querySelectorAll('.tabs button').forEach(button => {
  button.addEventListener('click', function() {
    document.querySelectorAll('.tabs button').forEach(btn => btn.classList.remove('tab-button-active'));
    this.classList.add('tab-button-active');
  });
});

document.addEventListener('DOMContentLoaded', function() {
  document.querySelector('.tabs button').classList.add('tab-button-active');
});

document.addEventListener("DOMContentLoaded", () => {
  window.chrome.webview.addEventListener('message', applySettings);
});

document.querySelectorAll('.custom-dropdown').forEach(dropdown => {
  const selected = dropdown.querySelector('.custom-dropdown-selected');
  const options = dropdown.querySelector('.custom-dropdown-options');
  const hiddenInput = document.getElementById('hiddenSelector');

  selected.addEventListener('click', () => {
    options.style.display = options.style.display === 'block' ? 'none' : 'block';
  });

  options.querySelectorAll('[data-value]').forEach(option => {
    option.addEventListener('click', () => {
      const value = option.getAttribute('data-value');
      selected.textContent = option.textContent;
      hiddenInput.value = value;
      options.style.display = 'none';
    });
  });

  document.addEventListener('click', e => {
    if (!dropdown.contains(e.target)) options.style.display = 'none';
  });
});

document.querySelectorAll('.custom-dropdown-options div[data-value]').forEach(option => {
  option.addEventListener('click', function () {
    const selected = this.closest('.custom-dropdown').querySelector('.custom-dropdown-selected');
    const text = this.textContent.trim();
    const img = this.querySelector('img');
    if (img) {
      selected.innerHTML = '';
      selected.appendChild(img.cloneNode(true));
      selected.append(' ' + text);
    } else {
      selected.textContent = text;
    }
  });
});
