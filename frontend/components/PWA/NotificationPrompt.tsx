"use client";

import { useState, useEffect, useRef } from "react";
import { Bell, X } from "lucide-react";
import { usePushNotifications } from "@/hooks/usePushNotifications";

export default function NotificationPrompt() {
  const { permission, isSupported, subscribe, isSubscribed } =
    usePushNotifications();
  const [show, setShow] = useState(false);
  const [dismissed, setDismissed] = useState(false);
  const [isClosing, setIsClosing] = useState(false);
  const mountedRef = useRef(true);

  useEffect(() => {
    const wasDismissed = localStorage.getItem("notification_prompt_dismissed");
    if (wasDismissed === "true") {
      setDismissed(true);
      return;
    }

    let timer: NodeJS.Timeout | undefined;

    if (isSupported && permission === "default" && !isSubscribed) {
      timer = setTimeout(() => {
        setShow(true);
      }, 3000);
    }

    return () => {
      mountedRef.current = false;
      if (timer) {
        clearTimeout(timer);
      }
    };
  }, [isSupported, permission, isSubscribed]);

  const handleEnable = async () => {
    const success = await subscribe();
    if (success) {
      setIsClosing(true);
      setTimeout(() => setShow(false), 250);
    }
  };

  const handleDismiss = () => {
    setIsClosing(true);
    setTimeout(() => {
      setShow(false);
      setDismissed(true);
      localStorage.setItem("notification_prompt_dismissed", "true");
    }, 250);
  };

  if (!show || dismissed) return null;

  return (
    <div className={`fixed bottom-20 left-4 right-4 bg-white/95 backdrop-blur-xl rounded-2xl shadow-elevated p-4 z-40 border border-neutral-200/60 ${isClosing ? 'animate-modal-exit' : 'animate-slide-up'}`}>
      <div className="flex items-start gap-3">
        <div className="flex-shrink-0 w-10 h-10 rounded-full bg-primary-coral/10 flex items-center justify-center">
          <Bell size={20} className="text-primary-coral" strokeWidth={2} />
        </div>

        <div className="flex-1 min-w-0">
          <h3 className="font-semibold text-sm text-neutral-900 mb-0.5">알림 받기</h3>
          <p className="text-xs text-neutral-500 mb-3">
            새 메시지가 도착하면 알려드릴게요
          </p>

          <div className="flex gap-2">
            <button
              onClick={handleEnable}
              className="flex-1 text-sm px-4 py-2 bg-primary-coral text-white rounded-full font-medium active:opacity-80 transition-opacity"
            >
              알림 켜기
            </button>
            <button
              onClick={handleDismiss}
              className="flex-1 text-sm px-4 py-2 bg-neutral-100 text-neutral-700 rounded-full font-medium active:bg-neutral-200 transition-colors"
            >
              나중에
            </button>
          </div>
        </div>

        <button
          onClick={handleDismiss}
          className="flex-shrink-0 w-7 h-7 rounded-full hover:bg-neutral-100 flex items-center justify-center transition-colors active:bg-neutral-200"
        >
          <X size={16} className="text-neutral-400" strokeWidth={2} />
        </button>
      </div>
    </div>
  );
}
