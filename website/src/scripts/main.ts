import { gsap, ScrollTrigger, media, animateResults } from './animations';
import './sounds';
import './playful-interactions';
import './platform-downloads';

// Demo data stays in the page; this never reads or controls the visitor's machine.
const search = document.querySelector<HTMLInputElement>('#demo-search');
const rows = [...document.querySelectorAll<HTMLElement>('.demo-port-row')];
const filters = [
  ...document.querySelectorAll<HTMLButtonElement>('[data-filter]'),
];
const emptyState = document.querySelector<HTMLElement>('.demo-empty');
const count = document.querySelector<HTMLElement>('#result-count');
const status = document.querySelector<HTMLElement>('#demo-status');
let protocol = 'all';

function updateDemo() {
  const query = search?.value.trim().toLowerCase() ?? '';
  let shown = 0;
  animateResults(() => {
    rows.forEach((row) => {
      const matchesProtocol =
        protocol === 'all' || row.dataset.protocol === protocol;
      const matchesSearch =
        row.dataset.search?.toLowerCase().includes(query) ?? false;
      row.hidden = !(matchesProtocol && matchesSearch);
      if (!row.hidden) shown += 1;
    });
    if (emptyState) emptyState.hidden = shown > 0;
    if (count) count.textContent = String(shown);
    if (status)
      status.textContent =
        query || protocol !== 'all'
          ? shown > 0
            ? `找到 ${shown} 个匹配端口。示例列表已更新。`
            : '没有匹配的端口，试试其他关键词。'
          : '示例数据，可搜索端口、PID、应用或命令。';
  });
}

search?.addEventListener('input', updateDemo);
filters.forEach((button) => {
  button.addEventListener('click', () => {
    protocol = button.dataset.filter ?? 'all';
    filters.forEach((filter) => {
      const active = filter === button;
      filter.classList.toggle('active', active);
      filter.setAttribute('aria-pressed', String(active));
    });
    updateDemo();
  });
});

document.addEventListener('keydown', (event) => {
  const target = event.target;
  if (event.key !== '/' || event.metaKey || event.ctrlKey || event.altKey)
    return;
  if (
    target instanceof HTMLElement &&
    (target.isContentEditable || target.closest('input, textarea, select'))
  )
    return;
  if (!search) return;
  event.preventDefault();
  // Make the input focusable even if its scroll entrance has not played yet.
  gsap.getTweensOf('.demo-panel').forEach((tween) => tween.progress(1));
  search.focus({ preventScroll: true });
  search.scrollIntoView({
    block: 'center',
    behavior: matchMedia('(prefers-reduced-motion: reduce)').matches
      ? 'instant'
      : 'smooth',
  });
});

document
  .querySelectorAll<HTMLAnchorElement>('.mobile-nav a')
  .forEach((link) => {
    link.addEventListener('click', () =>
      link.closest('details')?.removeAttribute('open'),
    );
  });
document.querySelectorAll('.faq-item').forEach((item) => {
  item.addEventListener('toggle', () => ScrollTrigger.refresh());
});

document.fonts.ready.then(() => ScrollTrigger.refresh());
window.addEventListener('load', () => ScrollTrigger.refresh(), { once: true });
window.addEventListener('pagehide', (event) => {
  if (!event.persisted) media.revert();
});
