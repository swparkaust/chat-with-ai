import { useEffect, useRef } from "react";
import { scrollToBottom } from "@/lib/utils";
import { SCROLL_DEBOUNCE_MS } from "@/lib/constants";

/**
 * Custom hook to handle auto-scrolling to bottom of a container with debouncing
 * @param containerRef Reference to the scroll container
 * @param trigger Dependency that triggers the auto-scroll
 * @param isAtBottom Whether the container is currently scrolled to bottom
 */
export function useAutoScroll(
  containerRef: React.RefObject<HTMLElement | null>,
  trigger: unknown,
  isAtBottom: boolean
) {
  const scrollTimeoutRef = useRef<NodeJS.Timeout | null>(null);

  useEffect(() => {
    if (isAtBottom) {
      if (scrollTimeoutRef.current) {
        clearTimeout(scrollTimeoutRef.current);
      }

      scrollTimeoutRef.current = setTimeout(() => {
        scrollToBottom(containerRef.current);
        scrollTimeoutRef.current = null;
      }, SCROLL_DEBOUNCE_MS);
    }

    return () => {
      if (scrollTimeoutRef.current) {
        clearTimeout(scrollTimeoutRef.current);
        scrollTimeoutRef.current = null;
      }
    };
  }, [trigger, isAtBottom, containerRef]);
}
