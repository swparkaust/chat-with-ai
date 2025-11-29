"use client";

import { useState } from "react";
import ChatHeader from "@/components/Header/ChatHeader";
import MessageList from "./MessageList";
import ChatInput from "./ChatInput";
import ProfileSheet from "@/components/Profile/ProfileSheet";
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
    sendMessage,
    setTyping,
    markAsRead,
    loadMoreMessages,
  } = useConversation(conversationId);

  const [showProfile, setShowProfile] = useState(false);
  const isSeasonActive = conversation?.season?.active ?? true;

  const handleSendMessage = async (content: string) => {
    await sendMessage(content);
  };

  const handleTyping = (typing: boolean) => {
    setTyping(typing);
  };

  const handleMarkAsRead = (messageIds: number[]) => {
    markAsRead(messageIds);
  };

  if (error) {
    return (
      <div className="flex items-center justify-center h-full p-4 bg-gradient-to-b from-neutral-50 to-white">
        <div className="text-center bg-white rounded-2xl shadow-elevated p-6 max-w-sm border border-neutral-200/60">
          <p className="text-primary-red mb-2 font-semibold">오류가 발생했습니다</p>
          <p className="text-sm text-neutral-600">{error}</p>
        </div>
      </div>
    );
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
          onMarkAsRead={handleMarkAsRead}
        />
      )}

      {!isSeasonActive && (
        <div className="px-4 py-3 bg-neutral-50 border-t border-neutral-200/60 text-center">
          <p className="text-sm text-neutral-500">
            이 시즌은 종료되었습니다. 메시지를 보낼 수 없습니다.
          </p>
        </div>
      )}

      {isSeasonActive && (
        <ChatInput
          onSend={handleSendMessage}
          onTyping={handleTyping}
          disabled={loading}
        />
      )}

      {showProfile && (
        <ProfileSheet
          type="ai"
          onClose={() => setShowProfile(false)}
        />
      )}
    </div>
  );
}
