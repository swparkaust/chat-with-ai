"use client";

import { useState } from "react";
import ChatHeader from "@/components/Header/ChatHeader";
import MessageList from "./MessageList";
import ChatInput from "./ChatInput";
import ProfileSheet from "@/components/Profile/ProfileSheet";
import ErrorCard from "@/components/Common/ErrorCard";
import { useConversation } from "@/hooks/useConversation";
import type { User } from "@/types";

interface ChatContainerProps {
  user: User;
  conversationId?: number;
}

export default function ChatContainer({ user, conversationId }: ChatContainerProps) {
  const {
    conversation,
    messages,
    loading,
    error,
    aiTyping,
    hasMoreMessages,
    offlineNotice,
    retry,
    sendMessage,
    setTyping,
    markAsRead,
    loadMoreMessages,
    updateScrollPosition,
  } = useConversation(conversationId);

  const [showProfile, setShowProfile] = useState(false);
  const isSeasonActive = conversation?.season?.active ?? true;

  const handleSendMessage = async (content: string) => {
    await sendMessage(content);
  };

  if (error) {
    return <ErrorCard
        title="오류가 발생했습니다"
        message={error}
        onRetry={retry}
        backHref="/conversations"
        backLabel="대화 목록으로"
      />;
  }

  return (
    <div className="flex flex-col h-full w-full">
      <ChatHeader
        season={conversation?.season}
        onProfileClick={() => setShowProfile(true)}
      />

      {loading && messages.length === 0 ? (
        <div className="flex-1 flex items-center justify-center bg-white">
          <div className="text-center">
            <div className="w-12 h-12 border-3 border-neutral-200 border-t-primary-coral rounded-full animate-spin mx-auto mb-3"></div>
            <p className="text-sm text-neutral-500">대화를 불러오는 중...</p>
          </div>
        </div>
      ) : (
        <MessageList
          messages={messages}
          aiTyping={aiTyping}
          hasMore={hasMoreMessages}
          season={conversation?.season}
          onLoadMore={loadMoreMessages}
          onMarkAsRead={markAsRead}
          onScrollPositionChange={updateScrollPosition}
        />
      )}

      {offlineNotice && (
        <div className="px-4 py-2 bg-neutral-50 border-t border-neutral-200/60 text-center">
          <p className="text-xs text-neutral-500">
            오프라인 상태예요. 연결되면 메시지가 전송됩니다.
          </p>
        </div>
      )}

      {conversation &&
        (isSeasonActive ? (
          <ChatInput
            onSend={handleSendMessage}
            onTyping={setTyping}
            disabled={loading}
          />
        ) : (
          <div className="px-4 py-3 bg-neutral-50 border-t border-neutral-200/60 text-center">
            <p className="text-sm text-neutral-500">
              이 시즌은 종료되었습니다. 메시지를 보낼 수 없습니다.
            </p>
          </div>
        ))}

      {showProfile && (
        <ProfileSheet
          type="ai"
          onClose={() => setShowProfile(false)}
        />
      )}
    </div>
  );
}
