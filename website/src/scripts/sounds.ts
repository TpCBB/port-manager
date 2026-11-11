type Sound = 'hover' | 'click';

const toggle = document.querySelector<HTMLButtonElement>('[data-sound-toggle]');
const preferenceKey = 'port-manager:ui-sounds';
const urls: Record<Sound, string> = {
  hover: '/audio/button-hover.mp3',
  click: '/audio/button-click.mp3',
};
let enabled = false;
try {
  enabled = localStorage.getItem(preferenceKey) === 'on';
} catch {
  /* Storage is optional. */
}

let context: AudioContext | undefined;
let output: GainNode | undefined;
let loading: Promise<void> | undefined;
let playing: AudioBufferSourceNode | undefined;
const buffers = new Map<Sound, AudioBuffer>();
let generation = 0;
let keyboardInput = false;
let lastHover = -Infinity;

function updateToggle() {
  if (!toggle) return;
  toggle.setAttribute('aria-pressed', String(enabled));
  toggle.setAttribute('aria-label', enabled ? '关闭按钮音效' : '开启按钮音效');
  toggle.title = enabled ? '关闭按钮音效' : '开启按钮音效';
  toggle.querySelector<HTMLElement>('[data-sound-icon-on]')!.hidden = !enabled;
  toggle.querySelector<HTMLElement>('[data-sound-icon-off]')!.hidden = enabled;
}

function stop() {
  playing?.stop();
  playing = undefined;
}

function setEnabled(value: boolean) {
  enabled = value;
  generation += 1;
  if (!value) stop();
  try {
    localStorage.setItem(preferenceKey, value ? 'on' : 'off');
  } catch {
    /* Keep working without persistence. */
  }
  updateToggle();
}

function prepare() {
  if (!context) {
    context = new AudioContext();
    output = context.createGain();
    output.gain.value = 0.65;
    output.connect(context.destination);
  }
  // Resume directly inside the user's gesture, before waiting for any network I/O.
  const resumed =
    context.state === 'running' ? Promise.resolve() : context.resume();
  if (!loading) {
    const decoder = context;
    loading = Promise.all(
      (Object.keys(urls) as Sound[]).map(async (sound) => {
        const response = await fetch(urls[sound]);
        if (!response.ok) throw new Error('Sound could not be loaded');
        const buffer = await decoder.decodeAudioData(
          await response.arrayBuffer(),
        );
        buffers.set(sound, buffer);
      }),
    )
      .then(() => undefined)
      .catch((error) => {
        loading = undefined;
        throw error;
      });
  }
  return Promise.all([resumed, loading]);
}

function play(sound: Sound) {
  if (!enabled || document.hidden || context?.state !== 'running' || !output)
    return;
  const buffer = buffers.get(sound);
  if (!buffer) return;
  if (sound === 'hover') {
    const now = performance.now();
    if (now - lastHover < 75) return;
    lastHover = now;
  }
  stop();
  const source = context.createBufferSource();
  source.buffer = buffer;
  source.connect(output);
  source.onended = () => {
    source.disconnect();
    if (playing === source) playing = undefined;
  };
  playing = source;
  source.start();
}

function activate(click: boolean) {
  if (!enabled) return;
  const request = generation;
  void prepare()
    .then(() => {
      if (request === generation && click) play('click');
    })
    .catch(() => {
      if (request !== generation) return;
      setEnabled(false);
      if (toggle) toggle.title = '音效加载失败，点击重试';
    });
}

function control(target: EventTarget | null) {
  if (!(target instanceof Element)) return null;
  const element = target.closest<HTMLElement>('a[href], button, summary');
  if (
    !element ||
    element.matches(
      '[disabled], [aria-disabled="true"], [data-sound-toggle], .skip-link',
    )
  )
    return null;
  return element;
}

if (toggle && typeof AudioContext !== 'undefined') {
  toggle.hidden = false;
  updateToggle();
  toggle.addEventListener('click', () => {
    setEnabled(!enabled);
    if (enabled) activate(true);
  });
  document.addEventListener(
    'pointerdown',
    () => {
      keyboardInput = false;
      activate(false);
    },
    { capture: true, passive: true },
  );
  document.addEventListener(
    'keydown',
    (event) => {
      if (event.metaKey || event.ctrlKey || event.altKey || event.repeat)
        return;
      keyboardInput = true;
      activate(false);
    },
    true,
  );
  document.addEventListener(
    'pointerover',
    (event) => {
      if (event.pointerType !== 'mouse') return;
      const target = control(event.target);
      if (target && target !== control(event.relatedTarget)) play('hover');
    },
    { passive: true },
  );
  document.addEventListener('focusin', (event) => {
    if (keyboardInput && control(event.target)) play('hover');
  });
  // Capture before a button's own handler can disable it or change page state.
  document.addEventListener(
    'click',
    (event) => {
      if (control(event.target)) activate(true);
    },
    true,
  );
  document.addEventListener('visibilitychange', () => {
    if (document.hidden) stop();
  });
  window.addEventListener('pagehide', (event) => {
    generation += 1;
    stop();
    if (!event.persisted) void context?.close().catch(() => {});
  });
}
