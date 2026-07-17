"use client";

import { useState, useEffect, useRef, type ReactNode } from "react";
import { X } from "lucide-react";
import { useClosingTransition } from "@/hooks/useClosingTransition";
import { dismissPrompt, isPromptDismissed, subscribeToPromptDismissals } from "@/lib/utils";

interface PromptBannerProps {
  icon: ReactNode;
  title: string;
  description: string;
  storageKey: string;
  delayMs: number;
  available: boolean;
  // Omit both for an instruction-only banner (e.g. iOS install steps,
  // where no programmatic action exists — dismissal is the only button)
  acceptLabel?: string;
  dismissLabel: string;
  onAccept?: () => Promise<boolean>;
}

export default function PromptBanner({
  icon,
  title,
  description,
  storageKey,
  delayMs,
  available,
  acceptLabel,
  dismissLabel,
  onAccept,
}: PromptBannerProps) {
  const [show, setShow] = useState(false);
  const { isClosing, close } = useClosingTransition();
  const acceptPendingRef = useRef(false);

  useEffect(() => {
    // Re-derive visibility from scratch on every run — this reset is what
    // makes a banner whose availability flipped off and on wait delayMs
    // again instead of reappearing instantly with a latched show
    setShow(false);

    if (!available || isPromptDismissed(storageKey)) return;

    const timer = setTimeout(() => {
      setShow(true);
    }, delayMs);

    // A dismissal recorded in another tab retracts this banner too
    const unsubscribe = subscribeToPromptDismissals(storageKey, () => {
      clearTimeout(timer);
      setShow(false);
    });

    return () => {
      clearTimeout(timer);
      unsubscribe();
    };
  }, [available, delayMs, storageKey]);

  // isClosing gates: the exit keyframe only animates transform, so buttons
  // stay clickable for its 250ms — a tap during the exit must not fire the
  // native dialog or re-record a dismissal. acceptPendingRef gates accept
  // ONLY: onAccept can pend unboundedly (ignored permission prompt, open
  // install dialog), and dismiss must stay live for that whole window.
  const handleAccept = async () => {
    if (!onAccept || isClosing || acceptPendingRef.current) return;

    acceptPendingRef.current = true;
    try {
      const success = await onAccept();
      if (success) {
        close(() => setShow(false));
      }
    } finally {
      acceptPendingRef.current = false;
    }
  };

  const handleDismiss = () => {
    if (isClosing) return;

    dismissPrompt(storageKey);
    close(() => setShow(false));
  };

  if (!show || !available) return null;

  return (
    <div className={`fixed bottom-20 left-4 right-4 bg-white/95 backdrop-blur-xl rounded-2xl shadow-elevated p-4 z-40 border border-neutral-200/60 ${isClosing ? 'animate-modal-exit' : 'animate-slide-up'}`}>
      <div className="flex items-start gap-3">
        <div className="flex-shrink-0 w-10 h-10 rounded-full bg-primary-coral/10 flex items-center justify-center">
          {icon}
        </div>

        <div className="flex-1 min-w-0">
          <h3 className="font-semibold text-sm text-neutral-900 mb-0.5">{title}</h3>
          <p className="text-xs text-neutral-500 mb-3">{description}</p>

          <div className="flex gap-2">
            {acceptLabel && onAccept && (
              <button
                onClick={handleAccept}
                className="flex-1 text-sm px-4 py-2 bg-primary-coral text-white rounded-full font-medium active:opacity-80 transition-opacity"
              >
                {acceptLabel}
              </button>
            )}
            <button
              onClick={handleDismiss}
              className="flex-1 text-sm px-4 py-2 bg-neutral-100 text-neutral-700 rounded-full font-medium active:bg-neutral-200 transition-colors"
            >
              {dismissLabel}
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
