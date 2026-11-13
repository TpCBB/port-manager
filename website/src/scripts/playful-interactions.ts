import gsap from 'gsap';
import { Draggable } from 'gsap/Draggable';
import { ScrollTrigger } from 'gsap/ScrollTrigger';
import { playUISound } from './sounds';

gsap.registerPlugin(Draggable, ScrollTrigger);
const motion = gsap.matchMedia();

motion.add('(prefers-reduced-motion: no-preference)', (context) => {
  gsap.to('.reading-progress', {
    scaleX: 1,
    ease: 'none',
    scrollTrigger: { start: 0, end: 'max', scrub: 0.15 },
  });
  const image = document.querySelector<HTMLElement>('.product-image-wrap');
  if (image) {
    gsap
      .timeline({
        scrollTrigger: {
          trigger: '.product-stage',
          start: 'top 80%',
          end: 'bottom 30%',
          scrub: 0.55,
        },
      })
      .fromTo(
        '.scan-sweep',
        { y: 0, autoAlpha: 0 },
        { autoAlpha: 1, duration: 0.1 },
      )
      .to('.scan-sweep', {
        y: () => image.offsetHeight * 0.82,
        ease: 'none',
        duration: 0.8,
      })
      .to('.scan-sweep', { autoAlpha: 0, duration: 0.1 });
  }
  let wave: gsap.core.Timeline | undefined;
  context.add('wave', () => {
    if (
      wave?.isActive() ||
      gsap.getTweensOf('.hero-char').some((tween) => tween.isActive())
    )
      return;
    wave = gsap
      .timeline()
      .to('.hero-char', {
        y: -10,
        rotation: (index) => (index % 2 ? 3 : -3),
        duration: 0.14,
        stagger: 0.025,
        ease: 'power2.out',
      })
      .to('.hero-char', {
        y: 0,
        rotation: 0,
        duration: 0.55,
        stagger: 0.025,
        ease: 'elastic.out(1, 0.4)',
      });
  });
  const title = document.querySelector('#hero-title');
  title?.addEventListener('pointerenter', context.wave);
  return () => title?.removeEventListener('pointerenter', context.wave);
});

motion.add(
  '(pointer: fine) and (prefers-reduced-motion: no-preference)',
  () => {
    const cleanups: (() => void)[] = [];
    document
      .querySelectorAll<HTMLElement>('.button-primary')
      .forEach((button) => {
        const x = gsap.quickTo(button, 'x', {
          duration: 0.4,
          ease: 'power3.out',
        });
        const y = gsap.quickTo(button, 'y', {
          duration: 0.4,
          ease: 'power3.out',
        });
        const move = (event: PointerEvent) => {
          const box = button.getBoundingClientRect();
          x(((event.clientX - box.left) / box.width - 0.5) * 12);
          y(((event.clientY - box.top) / box.height - 0.5) * 8);
        };
        const leave = () => {
          x(0);
          y(0);
        };
        button.addEventListener('pointermove', move);
        button.addEventListener('pointerleave', leave);
        cleanups.push(() => {
          button.removeEventListener('pointermove', move);
          button.removeEventListener('pointerleave', leave);
        });
      });
    const hero = document.querySelector<HTMLElement>('.hero-copy');
    const eye = document.querySelector<HTMLElement>('.sticker-eye');
    if (hero && eye) {
      const x = gsap.quickTo(eye, 'x', { duration: 0.3 });
      const y = gsap.quickTo(eye, 'y', { duration: 0.3 });
      const move = (event: PointerEvent) => {
        const box = hero.getBoundingClientRect();
        x(
          gsap.utils.clamp(
            -3,
            3,
            ((event.clientX - box.left) / box.width - 0.5) * 6,
          ),
        );
        y(
          gsap.utils.clamp(
            -2,
            2,
            ((event.clientY - box.top) / box.height - 0.5) * 4,
          ),
        );
      };
      const leave = () => {
        x(0);
        y(0);
      };
      hero.addEventListener('pointermove', move);
      hero.addEventListener('pointerleave', leave);
      cleanups.push(() => {
        hero.removeEventListener('pointermove', move);
        hero.removeEventListener('pointerleave', leave);
      });
    }
    return () => cleanups.forEach((cleanup) => cleanup());
  },
);

let discardPointerClick = false;
const quips = [
  '端口：人在，勿扰。',
  '别拍了，监听还没停。',
  '服务：上个项目，我还在跑。',
  '预览看完了，服务还没下班。',
];
motion.add(
  {
    animated: '(prefers-reduced-motion: no-preference)',
    reduced: '(prefers-reduced-motion: reduce)',
  },
  (context) => {
    const playground = document.querySelector<HTMLElement>('.port-playground');
    const scene = document.querySelector<HTMLElement>('.playground-scene');
    const shell = document.querySelector<HTMLElement>('.occupant-drag-shell');
    const card = document.querySelector<HTMLElement>('.occupant-card');
    const handle = document.querySelector<HTMLButtonElement>(
      '.occupant-drag-handle',
    );
    const socket = document.querySelector<HTMLElement>('.port-socket');
    const primary = document.querySelector<HTMLButtonElement>('.scene-button');
    const nudge = document.querySelector<HTMLButtonElement>('.scene-nudge');
    const hint = document.querySelector<HTMLElement>('.playground-hint');
    const speech = document.querySelector<HTMLElement>('.occupant-speech');
    if (
      !playground ||
      !scene ||
      !shell ||
      !card ||
      !handle ||
      !socket ||
      !primary ||
      !nudge ||
      !hint ||
      !speech
    )
      return;
    const animated = Boolean(context.conditions?.animated);
    let drag: Draggable | undefined;
    let bounced: gsap.core.Tween | undefined;
    let shaken: gsap.core.Timeline | undefined;
    let dragged = false;
    let taps = 0;
    const busy = () =>
      primary.disabled || playground.dataset.animating === 'true';
    const occupied = () => playground.dataset.state === 'busy';
    const finishEntrance = () => gsap.getById('tenant-entrance')?.progress(1);
    const inspect = () =>
      context.ignore(() =>
        playground.dispatchEvent(new CustomEvent('port-manager:inspect')),
      );

    const clearDrag = () => {
      bounced?.kill();
      shaken?.kill();
      gsap.set(shell, { x: 0, y: 0, scale: 1, rotation: 0 });
      gsap.set(card, { clearProps: 'transform' });
      drag?.update();
      delete playground.dataset.dragging;
      delete playground.dataset.dropReady;
    };
    context.add('synchronize', () => {
      clearDrag();
      const canAct = !busy();
      handle.disabled = !canAct;
      nudge.disabled = !canAct;
      if (animated && canAct && occupied()) drag?.enable();
      else drag?.disable();
      hint.textContent =
        animated && occupied()
          ? '拖动卡片到左边查看来源，或点按钮演示完整流程。'
          : '点按钮演示查看来源、确认结束和重新扫描。';
      speech.textContent = '（页面关了，服务还在跑）';
    });
    context.add('start', () => {
      bounced?.kill();
      shaken?.kill();
      delete playground.dataset.dragging;
      delete playground.dataset.dropReady;
      drag?.disable();
      handle.disabled = true;
      nudge.disabled = true;
    });
    context.add('handleClick', (event: MouseEvent) => {
      if (
        busy() ||
        ((dragged || discardPointerClick) &&
          (event.detail !== 0 || !event.isTrusted))
      )
        return;
      finishEntrance();
      playUISound('click');
      inspect();
    });
    context.add('handleHover', (event: PointerEvent) => {
      if (!busy() && event.pointerType === 'mouse') playUISound('hover');
    });
    context.add('handleFocus', () => {
      if (!busy() && handle.matches(':focus-visible')) playUISound('hover');
    });
    context.add('newPress', () => {
      discardPointerClick = false;
      dragged = false;
    });
    context.add('nudge', () => {
      if (busy() || drag?.isDragging || shaken?.isActive()) return;
      if (!occupied()) {
        inspect();
        return;
      }
      finishEntrance();
      clearDrag();
      speech.textContent = quips[taps++ % quips.length];
      if (!animated) return;
      shaken = gsap
        .timeline({ onComplete: () => drag?.update() })
        .to(shell, { y: -18, scale: 1.03, duration: 0.16, ease: 'power2.out' })
        .to(shell, {
          y: 0,
          scale: 1,
          duration: 0.7,
          ease: 'elastic.out(1, 0.3)',
        })
        .to(
          card,
          {
            rotation: '+=7',
            duration: 0.07,
            repeat: 3,
            yoyo: true,
            ease: 'none',
          },
          0,
        )
        .fromTo(
          '.wild-port',
          { y: 9, scale: 0.7, autoAlpha: 0 },
          {
            y: 0,
            scale: 1,
            autoAlpha: 1,
            duration: 0.4,
            stagger: 0.08,
            ease: 'back.out(2)',
          },
          0.05,
        );
    });

    if (animated) {
      const tilt = gsap.quickTo(card, 'rotation', {
        duration: 0.22,
        ease: 'power2.out',
      });
      context.add('press', () => {
        if (busy()) return;
        finishEntrance();
        bounced?.kill();
        shaken?.kill();
        dragged = false;
      });
      context.add('dragStart', () => {
        dragged = true;
        discardPointerClick = true;
        playground.dataset.dragging = 'true';
        speech.textContent = '拖到左侧，查看这个服务的来源。';
      });
      context.add('dragMove', () => {
        if (!drag) return;
        tilt(gsap.utils.clamp(-12, 12, drag.x * 0.045));
        playground.dataset.dropReady = String(drag.hitTest(socket, '30%'));
      });
      context.add('dragEnd', () => {
        if (!drag || busy()) return;
        const hit = drag.hitTest(socket, '30%');
        delete playground.dataset.dragging;
        delete playground.dataset.dropReady;
        if (hit) {
          playUISound('click');
          inspect();
        } else {
          speech.textContent = '跑？还是得回 localhost。';
          tilt(0);
          bounced = gsap.to(shell, {
            x: 0,
            y: 0,
            duration: 0.85,
            ease: 'elastic.out(1, 0.38)',
            onComplete: () => drag?.update(),
          });
        }
      });
      [drag] = Draggable.create(shell, {
        type: 'x,y',
        trigger: handle,
        bounds: scene,
        dragClickables: true,
        minimumMovement: 5,
        edgeResistance: 0.85,
        activeCursor: 'grabbing',
        onPress: context.press,
        onDragStart: context.dragStart,
        onDrag: context.dragMove,
        onDragEnd: context.dragEnd,
      });
      playground.dataset.dragReady = 'true';
    } else delete playground.dataset.dragReady;

    handle.addEventListener('click', context.handleClick);
    handle.addEventListener('pointerdown', context.newPress, true);
    handle.addEventListener('pointerenter', context.handleHover);
    handle.addEventListener('focus', context.handleFocus);
    nudge.addEventListener('click', context.nudge);
    playground.addEventListener(
      'port-manager:scene-change',
      context.synchronize,
    );
    playground.addEventListener('port-manager:scene-start', context.start);
    context.synchronize();
    return () => {
      drag?.kill();
      handle.removeEventListener('click', context.handleClick);
      handle.removeEventListener('pointerdown', context.newPress, true);
      handle.removeEventListener('pointerenter', context.handleHover);
      handle.removeEventListener('focus', context.handleFocus);
      nudge.removeEventListener('click', context.nudge);
      playground.removeEventListener(
        'port-manager:scene-change',
        context.synchronize,
      );
      playground.removeEventListener('port-manager:scene-start', context.start);
      delete playground.dataset.dragReady;
      delete playground.dataset.dragging;
      delete playground.dataset.dropReady;
    };
  },
);

window.addEventListener('pagehide', (event) => {
  if (!event.persisted) motion.revert();
});
