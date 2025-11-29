"use client";

import { useState, useEffect, useRef } from "react";
import { Smartphone, X } from "lucide-react";
import { usePWAInstall } from "@/hooks/usePWAInstall";

export default function InstallPrompt() {
  const { isInstallable, promptInstall } = usePWAInstall();
  const [show, setShow] = useState(false);
  const [dismissed, setDismissed] = useState(false);
  const [isClosing, setIsClosing] = useState(false);
  const mountedRef = useRef(true);

  useEffect(() => {
    const wasDismissed = localStorage.getItem("install_prompt_dismissed");
    if (wasDismissed === "true") {
      setDismissed(true);
      return;
    }

    let timer: NodeJS.Timeout | undefined;

    if (isInstallable) {
      timer = setTimeout(() => {
        setShow(true);
      }, 5000);
    }

    return () => {
      mountedRef.current = false;
      if (timer) {
        clearTimeout(timer);
      }
    };
  }, [isInstallable]);

  const handleInstall = async () => {
    const success = await promptInstall();
    if (success || !isInstallable) {
      setIsClosing(true);
      setTimeout(() => setShow(false), 250);
    }
  };

  const handleDismiss = () => {
    setIsClosing(true);
    setTimeout(() => {
      setShow(false);
      setDismissed(true);
      localStorage.setItem("install_prompt_dismissed", "true");
    }, 250);
  };

  if (!show || dismissed || !isInstallable) return null;

  return (
    <div className={`fixed bottom-20 left-4 right-4 bg-white/95 backdrop-blur-xl rounded-2xl shadow-elevated p-4 z-40 border border-neutral-200/60 ${isClosing ? 'animate-modal-exit' : 'animate-slide-up'}`}>
      <div className="flex items-start gap-3">
        <div className="flex-shrink-0 w-10 h-10 rounded-full bg-primary-coral/10 flex items-center justify-center">
          <Smartphone size={20} className="text-primary-coral" strokeWidth={2} />
        </div>

        <div className="flex-1 min-w-0">
          <h3 className="font-semibold text-sm text-neutral-900 mb-0.5">홈 화면에 추가</h3>
          <p className="text-xs text-neutral-500 mb-3">
            앱처럼 빠르고 편리하게 사용하세요
          </p>

          <div className="flex gap-2">
            <button
              onClick={handleInstall}
              className="flex-1 text-sm px-4 py-2 bg-primary-coral text-white rounded-full font-medium active:opacity-80 transition-opacity"
            >
              설치하기
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
