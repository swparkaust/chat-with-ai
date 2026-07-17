"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { useAuth } from "@/hooks/useAuth";
import { useAppState } from "@/hooks/useAppState";
import { useOnboarding } from "@/hooks/useOnboarding";
import { useDocumentTitle } from "@/hooks/useDocumentTitle";
import { apiClient } from "@/lib/api";
import LoadingScreen from "@/components/Loading/LoadingScreen";
import ConversationsList from "@/components/Conversations/ConversationsList";
import ProfileSheet from "@/components/Profile/ProfileSheet";
import OnboardingFlow from "@/components/Onboarding/OnboardingFlow";
import NotificationPrompt from "@/components/PWA/NotificationPrompt";
import InstallPrompt from "@/components/PWA/InstallPrompt";
import ErrorCard from "@/components/Common/ErrorCard";

export default function ConversationsPage() {
  const router = useRouter();
  const { user, loading: authLoading, error: authError, authenticate } = useAuth();
  const { needsOnboarding, loading: onboardingLoading, completeOnboarding } = useOnboarding();
  const { appState } = useAppState();
  useDocumentTitle();
  const [showProfile, setShowProfile] = useState(false);
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    setMounted(true);
  }, []);

  const handleOnboardingComplete = async () => {
    completeOnboarding();

    try {
      const response = await apiClient.getCurrentConversation();
      if (response.data?.conversation?.id) {
        router.push(`/conversations/${response.data.conversation.id}`);
      }
    } catch (error) {
      console.error("Failed to fetch conversation:", error);
    }
  };

  if (!mounted || authLoading || onboardingLoading) {
    return <LoadingScreen />;
  }

  if (authError) {
    return <ErrorCard title="인증 오류가 발생했습니다" message={authError} onRetry={authenticate} />;
  }

  if (!user) {
    return <LoadingScreen />;
  }

  if (needsOnboarding) {
    return <OnboardingFlow onComplete={handleOnboardingComplete} />;
  }

  return (
    <>
      <main className="h-full w-full overflow-hidden">
        <ConversationsList user={user} appState={appState} onProfileClick={() => setShowProfile(true)} />
      </main>

      {showProfile && (
        <ProfileSheet type="user" onClose={() => setShowProfile(false)} />
      )}

      <NotificationPrompt />
      <InstallPrompt />
    </>
  );
}
