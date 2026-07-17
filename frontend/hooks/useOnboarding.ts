import { useState, useEffect } from "react";
import { ONBOARDING_COMPLETED_KEY } from "@/lib/constants";

export function useOnboarding() {
  const [needsOnboarding, setNeedsOnboarding] = useState(false);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    checkOnboardingStatus();
  }, []);

  const checkOnboardingStatus = () => {
    if (typeof window === "undefined") return;

    const hasCompletedOnboarding = localStorage.getItem(ONBOARDING_COMPLETED_KEY);

    if (!hasCompletedOnboarding) {
      setNeedsOnboarding(true);
    }

    setLoading(false);
  };

  const completeOnboarding = () => {
    if (typeof window === "undefined") return;

    localStorage.setItem(ONBOARDING_COMPLETED_KEY, "true");
    setNeedsOnboarding(false);
  };

  return {
    needsOnboarding,
    loading,
    completeOnboarding,
  };
}
