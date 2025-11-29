import { useState, useEffect } from "react";

export function useOnboarding() {
  const [needsOnboarding, setNeedsOnboarding] = useState(false);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    checkOnboardingStatus();
  }, []);

  const checkOnboardingStatus = () => {
    if (typeof window === "undefined") return;

    const hasCompletedOnboarding = localStorage.getItem("onboarding_completed");

    if (!hasCompletedOnboarding) {
      setNeedsOnboarding(true);
    }

    setLoading(false);
  };

  const completeOnboarding = () => {
    if (typeof window === "undefined") return;

    localStorage.setItem("onboarding_completed", "true");
    setNeedsOnboarding(false);
  };

  return {
    needsOnboarding,
    loading,
    completeOnboarding,
  };
}
