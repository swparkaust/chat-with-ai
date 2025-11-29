"use client";

import { useEffect, useState, useCallback } from "react";
import { useRouter } from "next/navigation";
import { MessageCircle } from "lucide-react";
import { apiClient } from "@/lib/api";
import { logger } from "@/lib/logger";
import ProfilePicture from "@/components/Common/ProfilePicture";
import type { ConversationSummary, User, AppState } from "@/types";

interface ConversationsListProps {
  user: User;
  appState: AppState | null;
  onProfileClick: () => void;
}

export default function ConversationsList({ user, appState, onProfileClick }: ConversationsListProps) {
  const router = useRouter();
  const [conversations, setConversations] = useState<ConversationSummary[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const loadConversations = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);
      const response = await apiClient.getConversations();
      if (response.data?.conversations) {
        setConversations(response.data.conversations);
      }
    } catch (err) {
      logger.error("Failed to load conversations:", err);
      setError("대화 목록을 불러올 수 없습니다");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadConversations();
  }, [loadConversations]);

  const handleConversationClick = (conversationId: number) => {
    router.push(`/conversations/${conversationId}`);
  };

  const formatDate = (dateString: string) => {
    const date = new Date(dateString);
    const now = new Date();
    const diff = now.getTime() - date.getTime();
    const days = Math.floor(diff / (1000 * 60 * 60 * 24));

    if (days === 0) {
      return date.toLocaleTimeString("ko-KR", { hour: "2-digit", minute: "2-digit" });
    } else if (days < 7) {
      return `${days}일 전`;
    } else if (days < 30) {
      return `${Math.floor(days / 7)}주 전`;
    } else if (days < 365) {
      return `${Math.floor(days / 30)}개월 전`;
    } else {
      return date.toLocaleDateString("ko-KR", { year: "numeric", month: "long" });
    }
  };

  if (loading) {
    return (
      <div className="h-full w-full flex items-center justify-center bg-gradient-to-b from-neutral-50 to-white">
        <div className="flex flex-col items-center gap-4">
          <div className="w-12 h-12 rounded-full border-4 border-primary-coral border-t-transparent animate-spin" />
          <p className="text-sm text-neutral-500">불러오는 중...</p>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="h-full w-full flex items-center justify-center bg-gradient-to-b from-neutral-50 to-white p-4">
        <div className="text-center">
          <p className="text-primary-red mb-2 font-semibold">{error}</p>
          <button
            onClick={loadConversations}
            className="mt-4 px-6 py-2.5 bg-primary-coral text-white rounded-full font-medium active:scale-95 transition-transform"
          >
            다시 시도
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="h-full w-full flex flex-col bg-gradient-to-b from-neutral-50 to-white">
      <div className="sticky top-0 z-10 bg-white/80 backdrop-blur-xl border-b border-neutral-200/60">
        <div className="px-4 py-3 flex items-center justify-between">
          <h1 className="text-3xl font-bold text-neutral-900">대화</h1>
          <button
            onClick={onProfileClick}
            className="active:scale-95 transition-transform"
          >
            <ProfilePicture
              imageUrl={user.profile_picture}
              size="sm"
              alt={user.name ?? ""}
              className="shadow-md"
            />
          </button>
        </div>
        {appState && (
          <div className="px-4 pb-3 flex items-center gap-2 text-xs">
            <span className="px-2 py-0.5 rounded-full bg-neutral-100 text-neutral-600">
              Season {appState.season_number}
            </span>
            <span className="text-neutral-300">•</span>
            <span className="text-neutral-500">{appState.active_users}명 참여중</span>
            <span className="text-neutral-300">•</span>
            <span className="text-neutral-400">v{appState.version}</span>
          </div>
        )}
      </div>

      {conversations.length === 0 ? (
        <div className="flex-1 flex items-center justify-center px-4">
          <div className="text-center">
            <div className="w-20 h-20 mx-auto mb-4 rounded-full bg-neutral-100 flex items-center justify-center">
              <MessageCircle size={40} className="text-neutral-400" strokeWidth={2} />
            </div>
            <p className="text-neutral-500 text-base">아직 대화가 없습니다</p>
          </div>
        </div>
      ) : (
        <div className="flex-1 overflow-y-auto">
          {conversations.map((conversation, index) => (
            <button
              key={conversation.id}
              onClick={() => handleConversationClick(conversation.id)}
              className="w-full px-4 py-3.5 flex items-center gap-3 bg-white hover:bg-neutral-50/80 active:bg-neutral-100/80 transition-colors border-b border-neutral-100/60"
            >
              <div className="relative flex-shrink-0">
                <ProfilePicture
                  imageUrl={conversation.profile_picture}
                  size="md"
                  alt={conversation.full_name}
                />
                {!conversation.active && (
                  <div className="absolute -bottom-0.5 -right-0.5 w-4 h-4 bg-neutral-400 rounded-full border-2 border-white" />
                )}
              </div>

              <div className="flex-1 min-w-0 text-left">
                <div className="flex items-baseline justify-between mb-0.5">
                  <h3 className="font-semibold text-neutral-900 truncate">
                    {conversation.full_name}
                  </h3>
                  <span className="text-xs text-neutral-500 ml-2 flex-shrink-0">
                    {formatDate(conversation.last_message_at)}
                  </span>
                </div>
                <div className="flex items-center justify-between">
                  <p className="text-sm text-neutral-500 truncate">
                    {conversation.last_message_preview || (conversation.active ? "진행 중인 대화" : "종료된 대화")}
                  </p>
                  {conversation.unread_count > 0 && (
                    <span className="flex-shrink-0 ml-2 min-w-[20px] h-5 px-1.5 bg-primary-red text-white text-xs font-semibold rounded-full flex items-center justify-center">
                      {conversation.unread_count > 99 ? "99+" : conversation.unread_count}
                    </span>
                  )}
                </div>
              </div>
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
