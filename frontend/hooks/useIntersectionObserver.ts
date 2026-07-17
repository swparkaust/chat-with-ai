import { useEffect, useRef, useState } from "react";

interface UseIntersectionObserverOptions {
  threshold?: number | number[];
  root?: Element | null;
  rootMargin?: string;
  freezeOnceVisible?: boolean;
}

/**
 * Hook to detect when an element is visible in the viewport
 * Used for read receipts and lazy loading
 */
export function useIntersectionObserver(
  options: UseIntersectionObserverOptions = {}
): [React.RefObject<HTMLDivElement>, boolean] {
  const {
    threshold = 0,
    root = null,
    rootMargin = "0px",
    freezeOnceVisible = false,
  } = options;

  const elementRef = useRef<HTMLDivElement>(null);
  const frozenRef = useRef(false);
  const [isVisible, setIsVisible] = useState(false);

  useEffect(() => {
    const element = elementRef.current;
    if (!element || frozenRef.current) return;

    const observer = new IntersectionObserver(
      ([entry]) => {
        setIsVisible(entry.isIntersecting);

        if (freezeOnceVisible && entry.isIntersecting) {
          frozenRef.current = true;
          observer.disconnect();
        }
      },
      {
        threshold,
        root,
        rootMargin,
      }
    );

    observer.observe(element);

    return () => {
      observer.disconnect();
    };
  }, [threshold, root, rootMargin, freezeOnceVisible]);

  return [elementRef, isVisible];
}
