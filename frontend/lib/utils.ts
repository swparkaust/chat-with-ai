import { format, formatDistanceToNow, isToday, isYesterday } from "date-fns";
import { ko } from "date-fns/locale";
import { SCROLL_THRESHOLD_PX } from "./constants";

export function formatMessageTime(dateString: string): string {
  const date = new Date(dateString);

  if (isToday(date)) {
    return format(date, "a h:mm", { locale: ko });
  } else if (isYesterday(date)) {
    return `어제 ${format(date, "a h:mm", { locale: ko })}`;
  } else {
    return format(date, "M월 d일 a h:mm", { locale: ko });
  }
}

export function formatRelativeTime(dateString: string): string {
  const date = new Date(dateString);
  return formatDistanceToNow(date, { addSuffix: true, locale: ko });
}

export function generateDeviceId(): string {
  return `device_${Date.now()}_${Math.random().toString(36).substring(2, 15)}`;
}

export function supportsServiceWorker(): boolean {
  return typeof window !== "undefined" && "serviceWorker" in navigator;
}

export function supportsPushNotifications(): boolean {
  return (
    typeof window !== "undefined" &&
    "PushManager" in window &&
    "Notification" in window
  );
}

/**
 * Convert a base64 string to Uint8Array (for VAPID key)
 */
export function urlBase64ToUint8Array(base64String: string): Uint8Array {
  const padding = "=".repeat((4 - (base64String.length % 4)) % 4);
  const base64 = (base64String + padding)
    .replace(/-/g, "+")
    .replace(/_/g, "/");

  const rawData = window.atob(base64);
  const outputArray = new Uint8Array(rawData.length);

  for (let i = 0; i < rawData.length; ++i) {
    outputArray[i] = rawData.charCodeAt(i);
  }

  return outputArray;
}

export function debounce<T extends (...args: never[]) => unknown>(
  func: T,
  wait: number
): (...args: Parameters<T>) => void {
  let timeout: NodeJS.Timeout | null = null;

  return function executedFunction(...args: Parameters<T>) {
    const later = () => {
      timeout = null;
      func(...args);
    };

    if (timeout) {
      clearTimeout(timeout);
    }
    timeout = setTimeout(later, wait);
  };
}

export function scrollToBottom(
  element: HTMLElement | null,
  smooth: boolean = true
) {
  if (!element) return;

  element.scrollTo({
    top: element.scrollHeight,
    behavior: smooth ? "smooth" : "auto",
  });
}

export function isScrolledToBottom(
  element: HTMLElement | null,
  threshold: number = SCROLL_THRESHOLD_PX
): boolean {
  if (!element) return false;

  const { scrollTop, scrollHeight, clientHeight } = element;
  return scrollHeight - scrollTop - clientHeight < threshold;
}

export function isPWA(): boolean {
  if (typeof window === "undefined") return false;

  return (
    window.matchMedia("(display-mode: standalone)").matches ||
    (window.navigator as Navigator & { standalone?: boolean }).standalone === true
  );
}

export function vibrate(pattern: number | number[]): void {
  if (typeof window !== "undefined" && "vibrate" in navigator) {
    navigator.vibrate(pattern);
  }
}

export function getMessageTimeKey(dateString: string): string {
  const date = new Date(dateString);
  return format(date, "yyyy-MM-dd HH:mm");
}

/**
 * Add appropriate Korean particle "와" to a name
 * Korean grammar rule:
 * - Has 받침 (final consonant): add "이와" (e.g., "지영이와", "민준이와")
 * - No 받침: add "와" (e.g., "수와", "나라와")
 */
export function addKoreanParticleWa(name: string): string {
  if (!name) return name;

  const lastChar = name[name.length - 1];
  const lastCharCode = lastChar.charCodeAt(0);

  // Check if it's a Korean character (Hangul syllables)
  if (lastCharCode >= 0xac00 && lastCharCode <= 0xd7a3) {
    // Calculate if it has a final consonant (받침)
    const finalConsonantIndex = (lastCharCode - 0xac00) % 28;

    // Has 받침: add "이와", No 받침: add "와"
    return finalConsonantIndex !== 0 ? `${name}이와` : `${name}와`;
  }

  // For non-Korean characters, default to "와"
  return `${name}와`;
}
