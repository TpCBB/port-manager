import { download, downloadWindows, release } from '../data/product';

type Platform = 'macos' | 'windows' | 'other';
type PlatformNavigator = Navigator & {
  userAgentData?: { platform?: string };
};

function detectPlatform(): Platform {
  const browser = navigator as PlatformNavigator;
  const userAgent = browser.userAgent;
  const platform = browser.userAgentData?.platform || '';
  // iPadOS can present a desktop Mac user agent. It cannot run the Mac app.
  if (
    /Android|iPhone|iPad|iPod/i.test(userAgent) ||
    (/Mac/i.test(`${platform} ${userAgent}`) && browser.maxTouchPoints > 1)
  ) {
    return 'other';
  }
  if (/Win/i.test(platform) || /Windows/i.test(userAgent)) return 'windows';
  if (/Mac/i.test(platform) || /Macintosh|Mac OS X/i.test(userAgent))
    return 'macos';
  return 'other';
}

const platform = detectPlatform();
const choice = {
  macos: {
    label: '下载 macOS 版',
    href: download,
    requirements: 'macOS 13+ · Apple Silicon',
  },
  windows: {
    label: '下载 Windows 版',
    href: downloadWindows,
    requirements: 'Windows x64 · .NET Framework 4.x',
  },
  other: {
    label: '选择下载版本',
    href: release,
    requirements:
      'macOS 13+ / Apple Silicon · Windows x64 / .NET Framework 4.x',
  },
}[platform];

document.documentElement.dataset.downloadPlatform = platform;
document
  .querySelectorAll<HTMLAnchorElement>('[data-platform-download]')
  .forEach((button) => {
    button.href = choice.href;
    button.setAttribute('aria-label', choice.label);
    const label = button.querySelector<HTMLElement>('[data-download-label]');
    if (label && button.dataset.compact !== 'true')
      label.textContent = choice.label;
    button
      .querySelectorAll<HTMLElement>('[data-platform-icon]')
      .forEach((icon) => {
        icon.hidden = icon.dataset.platformIcon !== platform;
      });
  });
document
  .querySelectorAll<HTMLElement>('[data-download-requirements]')
  .forEach((note) => {
    note.textContent = choice.requirements;
  });
