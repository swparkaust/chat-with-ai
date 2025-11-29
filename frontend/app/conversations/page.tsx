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

export default function ConversationsPage() {
  const router = useRouter();
  const { user, loading: authLoading, error: authError } = useAuth();
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
    return (
      <div className="flex items-center justify-center h-full p-4">
        <div className="text-center bg-white rounded-2xl shadow-elevated p-6 max-w-sm">
          <p className="text-primary-red mb-2 font-semibold">인증 오류가 발생했습니다</p>
          <p className="text-sm text-neutral-600">{authError}</p>
        </div>
      </div>
    );
  }

  if (!user) {
    return <LoadingScreen />;
  }

  if (needsOnboarding) {
    return <OnboardingFlow user={user} onComplete={handleOnboardingComplete} />;
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
