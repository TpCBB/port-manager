import gsap from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';
import { Flip } from 'gsap/Flip';
import { tenants } from '../data/tenants';

gsap.registerPlugin(ScrollTrigger, Flip);
export { gsap, ScrollTrigger };
export const media = gsap.matchMedia();

let filterAnimator: ((mutate: () => void) => void) | undefined;
export function animateResults(mutate: () => void) {
  if (filterAnimator) filterAnimator(mutate);
  else mutate();
}

media.add('(prefers-reduced-motion: no-preference)', (context) => {
  const intro = gsap.timeline({
    defaults: { ease: 'power3.out', duration: 0.8 },
  });
  intro
    .from('.hero-copy .release-pill', { y: 14, autoAlpha: 0 }, 0)
    .from(
      '.hero-char',
      {
        yPercent: 130,
        rotation: 8,
        stagger: 0.038,
        duration: 0.95,
        ease: 'back.out(1.25)',
      },
      0.12,
    )
    .from(
      '.hero-description, .hero-terminal, .hero-actions, .system-note',
      { y: 16, autoAlpha: 0, stagger: 0.08 },
      0.55,
    )
    .from(
      '.hero-sticker',
      { autoAlpha: 0, scale: 0.65, stagger: 0.16, ease: 'back.out(1.8)' },
      0.6,
    )
    .fromTo(
      '.odometer-strip',
      { y: 0, yPercent: 0 },
      {
        y: 0,
        yPercent: -1000 / 11,
        duration: 1.7,
        stagger: 0.13,
        ease: 'power3.inOut',
      },
      0.6,
    )
    .to(
      '.hero-error-code',
      { x: 3, duration: 0.055, repeat: 3, yoyo: true, ease: 'none' },
      1,
    )
    .from(
      '.error-strike path',
      { strokeDashoffset: 1, duration: 0.45, ease: 'power2.inOut' },
      1.22,
    )
    .from('.hero-error-resolved', { x: -8, autoAlpha: 0, duration: 0.45 }, 1.55)
    .from('.product-stage', { y: 48, autoAlpha: 0, duration: 1 }, 0.85)
    .from(
      '.floating-label',
      { autoAlpha: 0, scale: 0.65, duration: 0.65, ease: 'back.out(1.7)' },
      1.45,
    );

  gsap.utils
    .toArray<HTMLElement>('[data-reveal]:not(.workflow-step)')
    .forEach((element) => {
      gsap.from(element, {
        y: 26,
        autoAlpha: 0,
        duration: 0.75,
        ease: 'power2.out',
        scrollTrigger: { trigger: element, start: 'top 91%', once: true },
      });
    });

  gsap
    .timeline({
      scrollTrigger: { trigger: '.menu-visual', start: 'top 85%', once: true },
    })
    .from('.menu-active', {
      scale: 0.45,
      autoAlpha: 0,
      duration: 0.4,
      ease: 'back.out(2)',
    })
    .from(
      '.menubar-image',
      {
        y: -24,
        scaleY: 0.35,
        rotation: -4,
        autoAlpha: 0,
        duration: 0.8,
        ease: 'back.out(1.1)',
      },
      0.2,
    )
    .from('.menu-pointer', { autoAlpha: 0, duration: 0.2 }, 0.25);

  gsap
    .timeline({
      id: 'tenant-entrance',
      scrollTrigger: {
        trigger: '.port-playground',
        start: 'top 85%',
        once: true,
      },
    })
    .from('.wild-port', {
      y: 17,
      scale: 0.65,
      autoAlpha: 0,
      duration: 0.45,
      stagger: 0.16,
      ease: 'back.out(1.8)',
    })
    .from(
      '.occupant-card',
      {
        x: 50,
        y: 45,
        rotation: 8,
        autoAlpha: 0,
        duration: 0.8,
        ease: 'back.out(1.8)',
      },
      0.2,
    );
  gsap.from('.workflow-step', {
    x: (index) => (index - 1) * 35,
    y: 28,
    rotation: (index) => (index - 1) * 5,
    autoAlpha: 0,
    stagger: 0.12,
    duration: 0.8,
    ease: 'back.out(1.4)',
    scrollTrigger: { trigger: '.workflow-steps', start: 'top 90%', once: true },
  });
  gsap.from('.download-inner > img', {
    y: 20,
    rotation: -15,
    scale: 0.7,
    duration: 0.85,
    ease: 'back.out(1.8)',
    scrollTrigger: {
      trigger: '.download-section',
      start: 'top 85%',
      once: true,
    },
  });

  let filterTween: gsap.core.Timeline | undefined;
  context.add('filterResults', (mutate: () => void) => {
    filterTween?.progress(1);
    filterTween?.kill();
    const rows = gsap.utils.toArray<HTMLElement>('.demo-port-row');
    const state = Flip.getState(rows);
    mutate();
    filterTween = Flip.from(state, {
      targets: rows.filter((row) => !row.hidden),
      duration: 0.35,
      ease: 'power2.out',
      scale: true,
      onEnter: (elements) =>
        gsap.fromTo(
          elements,
          { autoAlpha: 0, y: 8 },
          { autoAlpha: 1, y: 0, duration: 0.25, stagger: 0.035 },
        ),
    });
  });
  filterAnimator = context.filterResults;
  return () => {
    filterAnimator = undefined;
  };
});

media.add(
  '(min-width: 768px) and (prefers-reduced-motion: no-preference)',
  () => {
    gsap.to('.floating-label', {
      y: -36,
      rotation: -3,
      ease: 'none',
      scrollTrigger: {
        trigger: '.product-stage',
        start: 'top 80%',
        end: 'bottom top',
        scrub: 0.8,
      },
    });
    gsap.to('.hero-sticker', {
      y: -70,
      ease: 'none',
      scrollTrigger: {
        trigger: '.hero',
        start: 'top top',
        end: 'bottom top',
        scrub: 0.8,
      },
    });
    gsap.fromTo(
      '.download-watermark',
      { y: 28 },
      {
        y: -20,
        ease: 'none',
        scrollTrigger: {
          trigger: '.download-section',
          start: 'top bottom',
          end: 'bottom bottom',
          scrub: 0.9,
        },
      },
    );
  },
);

media.add(
  '(min-width: 1100px) and (pointer: fine) and (prefers-reduced-motion: no-preference)',
  () => {
    const stage = document.querySelector<HTMLElement>('.product-stage');
    const image = document.querySelector<HTMLElement>('.product-image-wrap');
    if (!stage || !image) return;
    const rotateX = gsap.quickTo(image, 'rotationX', {
      duration: 0.7,
      ease: 'power2.out',
    });
    const rotateY = gsap.quickTo(image, 'rotationY', {
      duration: 0.7,
      ease: 'power2.out',
    });
    const move = (event: PointerEvent) => {
      const box = stage.getBoundingClientRect();
      rotateX(-((event.clientY - box.top) / box.height - 0.5) * 4);
      rotateY(((event.clientX - box.left) / box.width - 0.5) * 4);
    };
    const reset = () => {
      rotateX(0);
      rotateY(0);
    };
    stage.addEventListener('pointermove', move);
    stage.addEventListener('pointerleave', reset);
    return () => {
      stage.removeEventListener('pointermove', move);
      stage.removeEventListener('pointerleave', reset);
    };
  },
);

// The playground is a fictional illustration. It never queries the host machine.
const playground = document.querySelector<HTMLElement>('.port-playground');
const sceneButton = document.querySelector<HTMLButtonElement>('.scene-button');
const sceneLabel = document.querySelector<HTMLElement>('.scene-button-label');
const sceneStatus = document.querySelector<HTMLElement>('#scene-status');
let sceneState: 'busy' | 'free' = 'busy';
let tenantIndex = 0;
let sceneContext: gsap.Context | undefined;

function notifyScene(name: string) {
  const dispatch = () => playground?.dispatchEvent(new CustomEvent(name));
  // Scene observers own their own animation context; do not nest the contexts.
  if (sceneContext) sceneContext.ignore(dispatch);
  else dispatch();
}

function identifyTenant() {
  if (!playground) return;
  const tenant = tenants[tenantIndex];
  const name = playground.querySelector<HTMLElement>('.occupant-name');
  const icon = playground.querySelector<HTMLElement>('.occupant-icon');
  const command = playground.querySelector<HTMLElement>('.occupant-command');
  if (name) name.textContent = tenant.process;
  if (icon) icon.textContent = tenant.icon;
  if (command) command.textContent = tenant.command;
}

function renderScene() {
  if (!playground || !sceneButton || !sceneLabel || !sceneStatus) return;
  const tenant = tenants[tenantIndex];
  playground.dataset.state = sceneState;
  playground.dataset.port = tenant.port;
  const values: Record<string, string> = {
    port: `:${tenant.port}`,
    process: tenant.process,
    pid: tenant.pid,
    command: tenant.command,
    directory: tenant.directory,
    quote: tenant.quote,
    stamp: tenant.stamp,
  };
  Object.entries(values).forEach(([key, value]) => {
    playground
      .querySelectorAll<HTMLElement>(`[data-tenant-${key}]`)
      .forEach((element) => {
        element.textContent = value;
        if (key === 'command') element.title = value;
      });
  });
  const name = playground.querySelector<HTMLElement>('.occupant-name');
  const icon = playground.querySelector<HTMLElement>('.occupant-icon');
  const command = playground.querySelector<HTMLElement>('.occupant-command');
  const caption = playground.querySelector<HTMLElement>('.free-port-caption');
  if (name) name.textContent = '待确认的服务';
  if (icon) icon.textContent = '?';
  if (command) command.textContent = '来源：待查看';
  if (caption)
    caption.textContent = `示例：确认后结束 ${tenant.process}，重新扫描端口。`;
  if (sceneState === 'free') identifyTenant();
  sceneButton.disabled = false;
  playground.dataset.animating = 'false';
  sceneLabel.textContent =
    sceneState === 'free' ? '再看一个服务' : '演示查看与结束';
  sceneStatus.textContent =
    sceneState === 'free'
      ? `示例：已确认并结束 ${tenant.process}，:${tenant.port} 已释放。`
      : `示例：:${tenant.port} 正在运行，先核对是哪个项目。`;
  playground
    .querySelectorAll<HTMLElement>(
      '.occupant-motion, .inspector-ticket, .free-port, .port-socket, .socket-ring, .scene-particle, .wild-port',
    )
    .forEach((element) => {
      ['transform', 'opacity', 'visibility'].forEach((property) =>
        element.style.removeProperty(property),
      );
    });
  notifyScene('port-manager:scene-change');
}

media.add(
  {
    animated: '(prefers-reduced-motion: no-preference)',
    reduced: '(prefers-reduced-motion: reduce)',
  },
  (context) => {
    if (!playground || !sceneButton || !sceneLabel || !sceneStatus) return;
    sceneContext = context;
    const animated = context.conditions?.animated;
    renderScene();
    context.add('playScene', () => {
      if (sceneButton.disabled) return;
      const reset = sceneState === 'free';
      if (reset) tenantIndex = (tenantIndex + 1) % tenants.length;
      sceneState = reset ? 'busy' : 'free';
      gsap.getById('tenant-entrance')?.progress(1);
      if (!animated) {
        renderScene();
        return;
      }

      if (reset) renderScene();
      sceneButton.disabled = true;
      playground.dataset.animating = 'true';
      notifyScene('port-manager:scene-start');
      sceneLabel.textContent = reset
        ? '查看下一个服务…'
        : '正在演示查看与结束…';
      sceneStatus.textContent = reset
        ? `示例：换一个项目，查看 :${tenants[tenantIndex].port} 的服务。`
        : '示例：查看命令和目录，确认结束，再扫描端口。';
      const timeline = gsap.timeline({
        onComplete: renderScene,
        defaults: { ease: 'power2.out' },
      });
      if (reset) {
        timeline
          .from('.occupant-motion', {
            x: 100,
            y: 18,
            rotation: 12,
            autoAlpha: 0,
            duration: 0.7,
            ease: 'back.out(1.5)',
          })
          .from(
            '.wild-port',
            {
              y: 15,
              scale: 0.7,
              autoAlpha: 0,
              stagger: 0.1,
              duration: 0.4,
              ease: 'back.out(1.8)',
            },
            0.15,
          );
        return;
      }
      timeline
        .fromTo(
          '.inspector-ticket',
          { x: 30, y: 10, rotation: 5, autoAlpha: 0 },
          {
            x: 0,
            y: 0,
            rotation: -5,
            autoAlpha: 1,
            duration: 0.4,
            ease: 'back.out(1.2)',
          },
        )
        .call(identifyTenant, [], 0.3)
        .to('.wild-port', { autoAlpha: 0, duration: 0.25 }, 0.55)
        .to(
          '.occupant-motion',
          {
            x: -150,
            y: -125,
            rotation: -25,
            autoAlpha: 0,
            duration: 0.5,
            ease: 'power2.in',
          },
          0.55,
        )
        .to('.inspector-ticket', { x: 40, autoAlpha: 0, duration: 0.25 }, 0.85)
        .to(
          '.socket-ring',
          { rotation: 160, scale: 0.8, autoAlpha: 0, duration: 0.5 },
          0.55,
        )
        .to('.port-socket', { autoAlpha: 0, duration: 0.35 }, 0.7)
        .fromTo(
          '.free-port',
          { scale: 0.75, autoAlpha: 0 },
          { scale: 1, autoAlpha: 1, duration: 0.6, ease: 'back.out(1.8)' },
          1,
        )
        .fromTo(
          '.scene-particle',
          { x: 0, y: 0, scale: 1, autoAlpha: 1 },
          {
            x: (index) => Math.cos((index * Math.PI) / 5) * 115,
            y: (index) => Math.sin((index * Math.PI) / 5) * 75,
            rotation: (index) => index * 43,
            scale: 0.2,
            autoAlpha: 0,
            duration: 0.7,
            stagger: 0.012,
          },
          1,
        );
    });
    sceneButton.addEventListener('click', context.playScene);
    playground.addEventListener('port-manager:inspect', context.playScene);
    return () => {
      sceneButton.removeEventListener('click', context.playScene);
      playground.removeEventListener('port-manager:inspect', context.playScene);
      // Finish the requested state if the motion preference changes mid-animation.
      renderScene();
      sceneContext = undefined;
    };
  },
);
