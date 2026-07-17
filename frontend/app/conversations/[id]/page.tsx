"use client";

import { useEffect, useState } from "react";
import { useParams } from "next/navigation";
import { useAuth } from "@/hooks/useAuth";
import { useDocumentTitle } from "@/hooks/useDocumentTitle";
import LoadingScreen from "@/components/Loading/LoadingScreen";
import ChatContainer from "@/components/Chat/ChatContainer";
import NotificationPrompt from "@/components/PWA/NotificationPrompt";
import InstallPrompt from "@/components/PWA/InstallPrompt";
import ErrorCard from "@/components/Common/ErrorCard";

export default function ConversationPage() {
  const params = useParams();
  const conversationId = params.id ? parseInt(params.id as string, 10) : null;
  const { user, loading: authLoading, error: authError, authenticate } = useAuth();
  useDocumentTitle();
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    setMounted(true);
  }, []);

  if (!mounted || authLoading) {
    return <LoadingScreen />;
  }

  if (authError) {
    return <ErrorCard
        title="인증 오류가 발생했습니다"
        message={authError}
        onRetry={authenticate}
        backHref="/conversations"
        backLabel="대화 목록으로"
      />;
  }

  if (!user || !conversationId) {
    return <LoadingScreen />;
  }

  return (
    <>
      <main className="h-full w-full overflow-hidden">
        <ChatContainer user={user} conversationId={conversationId} />
      </main>
      <NotificationPrompt />
      <InstallPrompt />
    </>
  );
}
