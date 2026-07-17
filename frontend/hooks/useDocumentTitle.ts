import { useEffect } from "react";
import { useAppName } from "./useAppName";

export function useDocumentTitle() {
  const { appName } = useAppName();

  useEffect(() => {
    if (typeof document !== "undefined") {
      document.title = appName;
    }
  }, [appName]);
}
