import { useCallback, useEffect, useRef, useState } from "react";

// Must match the animate-modal-exit keyframe length in tailwind.config.ts
// ("modal-exit 250ms") — consumers apply that class while isClosing is true
const CLOSING_TRANSITION_MS = 250;

export function useClosingTransition() {
  const [isClosing, setIsClosing] = useState(false);
  const timerRef = useRef<NodeJS.Timeout | null>(null);
  const pendingRef = useRef<(() => void) | undefined>(undefined);

  useEffect(() => {
    return () => {
      // Flush, don't drop: a pending onClosed carries completion work the
      // consumer scheduled (persisting a flag, resetting parent state) that
      // must survive an unmount mid-animation. No isClosing reset here —
      // the component is unmounting.
      if (timerRef.current) {
        clearTimeout(timerRef.current);
        pendingRef.current?.();
      }
    };
  }, []);

  const close = useCallback((onClosed?: () => void) => {
    // One close per transition — a second tap during the exit animation
    // must not fire onClosed again
    if (timerRef.current) return;

    pendingRef.current = onClosed;
    setIsClosing(true);
    timerRef.current = setTimeout(() => {
      timerRef.current = null;
      pendingRef.current = undefined;
      try {
        onClosed?.();
      } finally {
        // Reset so a consumer that re-shows in the same mount (e.g. a banner
        // whose availability flips back on) doesn't render stuck in the
        // exit-animation state
        setIsClosing(false);
      }
    }, CLOSING_TRANSITION_MS);
  }, []);

  return { isClosing, close };
}
