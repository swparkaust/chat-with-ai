"use client";

import { useEffect, useState } from "react";
import { useParams } from "next/navigation";
import { useAuth } from "@/hooks/useAuth";
import { useDocumentTitle } from "@/hooks/useDocumentTitle";
import LoadingScreen from "@/components/Loading/LoadingScreen";
import ChatContainer from "@/components/Chat/ChatContainer";
import NotificationPrompt from "@/components/PWA/NotificationPrompt";
import InstallPrompt from "@/components/PWA/InstallPrompt";

export default function ConversationPage() {
  const params = useParams();
  const conversationId = params.id ? parseInt(params.id as string, 10) : null;
  const { user, loading: authLoading, error: authError } = useAuth();
  useDocumentTitle();
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    setMounted(true);
  }, []);

  if (!mounted || authLoading) {
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
