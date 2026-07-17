import { useState, useEffect, useRef } from "react";
import { apiClient } from "@/lib/api";
import { logger } from "@/lib/logger";
import {
  isPushSupported,
  supportsServiceWorker,
  supportsPushNotifications,
  urlBase64ToUint8Array,
} from "@/lib/utils";
import { flushPendingOnStartup } from "@/lib/offlineOutbox";

export function usePushNotifications() {
  const [permission, setPermission] = useState<NotificationPermission>("default");
  const [subscription, setSubscription] = useState<PushSubscription | null>(null);
  // Refs, not state: a second tap can land before a re-render, and a
  // state-reading closure would see the stale value
  const subscribingRef = useRef(false);
  const unsubscribingRef = useRef(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (typeof window === "undefined") return;

    if (supportsPushNotifications()) {
      setPermission(Notification.permission);
    }

    initializeServiceWorker();
  }, []);

  const initializeServiceWorker = async () => {
    if (!supportsServiceWorker()) {
      return;
    }

    try {
      const registration = await navigator.serviceWorker.register(
        "/service-worker.js"
      );

      const existingSubscription = await registration.pushManager.getSubscription();
      if (existingSubscription) {
        setSubscription(existingSubscription);
      }

      flushPendingOnStartup();
    } catch (err) {
      logger.error("Service worker registration failed:", err);
      setError("서비스 워커 등록에 실패했습니다");
    }
  };

  const subscribe = async () => {
    if (!isPushSupported()) {
      setError("푸시 알림이 지원되지 않습니다");
      return false;
    }

    if (subscribingRef.current) return false;

    subscribingRef.current = true;
    try {
      setError(null);

      const perm = await Notification.requestPermission();
      setPermission(perm);

      if (perm !== "granted") {
        setError("알림 권한이 거부되었습니다");
        return false;
      }

      const registration = await navigator.serviceWorker.ready;

      const vapidPublicKey = process.env.NEXT_PUBLIC_VAPID_PUBLIC_KEY;
      if (!vapidPublicKey) {
        throw new Error("VAPID public key not configured");
      }

      const pushSubscription = await registration.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: urlBase64ToUint8Array(vapidPublicKey) as BufferSource,
      });

      setSubscription(pushSubscription);

      const subscriptionJSON = pushSubscription.toJSON();
      await apiClient.createSubscription({
        endpoint: subscriptionJSON.endpoint!,
        p256dh_key: subscriptionJSON.keys!.p256dh!,
        auth_key: subscriptionJSON.keys!.auth!,
      });

      return true;
    } catch (err) {
      const message = (err as Error)?.message ?? "푸시 알림 구독에 실패했습니다";
      setError(message);
      logger.error("Push subscription error:", err);
      return false;
    } finally {
      subscribingRef.current = false;
    }
  };

  const unsubscribe = async () => {
    if (!subscription || unsubscribingRef.current) return false;

    unsubscribingRef.current = true;
    try {
      setError(null);

      await subscription.unsubscribe();

      await apiClient.deleteSubscription(subscription.endpoint);

      setSubscription(null);
      return true;
    } catch (err) {
      const message = (err as Error)?.message ?? "푸시 알림 구독 해제에 실패했습니다";
      setError(message);
      logger.error("Push unsubscribe error:", err);
      return false;
    } finally {
      unsubscribingRef.current = false;
    }
  };

  return {
    permission,
    subscription,
    error,
    subscribe,
    unsubscribe,
    isSubscribed: !!subscription,
    isSupported: isPushSupported(),
  };
}
