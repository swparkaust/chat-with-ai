"use client";

import { useEffect, useRef, useState, useCallback } from "react";
import { ArrowDown } from "lucide-react";
import MessageBubble from "./MessageBubble";
import TypingIndicator from "./TypingIndicator";
import { scrollToBottom, isScrolledToBottom, getMessageTimeKey } from "@/lib/utils";
import { READ_RECEIPT_DEBOUNCE_MS } from "@/lib/constants";
import { useAutoScroll } from "@/hooks/useAutoScroll";
import type { Message, Season } from "@/types";

interface MessageListProps {
  messages: Message[];
  aiTyping: boolean;
  hasMore: boolean;
  season?: Season;
  onLoadMore: () => void;
  onMarkAsRead: (messageIds: number[]) => void;
}

export default function MessageList({
  messages,
  aiTyping,
  hasMore,
  season,
  onLoadMore,
  onMarkAsRead,
}: MessageListProps) {
  const containerRef = useRef<HTMLDivElement>(null);
  const [isAtBottom, setIsAtBottom] = useState(true);
  const [unreadMessages, setUnreadMessages] = useState<Set<number>>(new Set());

  useAutoScroll(containerRef, messages.length, isAtBottom);
  useAutoScroll(containerRef, aiTyping, isAtBottom);

  const shouldShowSender = useCallback((message: Message, index: number): boolean => {
    if (index === 0) return true;
    const prevMessage = messages[index - 1];
    if (prevMessage.sender_type !== message.sender_type) return true;
    if (message.sender_type === "user") return false;

    return getMessageTimeKey(prevMessage.created_at) !== getMessageTimeKey(message.created_at);
  }, [messages]);

  const shouldShowTimestamp = useCallback((message: Message, index: number): boolean => {
    if (index === messages.length - 1) return true;
    const nextMessage = messages[index + 1];
    if (nextMessage.sender_type !== message.sender_type) return true;

    return getMessageTimeKey(message.created_at) !== getMessageTimeKey(nextMessage.created_at);
  }, [messages]);

  const handleScroll = useCallback(() => {
    const container = containerRef.current;
    if (!container) return;

    const atBottom = isScrolledToBottom(container);
    setIsAtBottom(atBottom);

    if (container.scrollTop === 0 && hasMore) {
      onLoadMore();
    }
  }, [hasMore, onLoadMore]);

  const handleMessageVisible = useCallback(
    (messageId: number) => {
      setUnreadMessages((prev) => {
        const updated = new Set(prev);
        updated.add(messageId);
        return updated;
      });
    },
    []
  );

  useEffect(() => {
    if (unreadMessages.size === 0) return;

    const timer = setTimeout(() => {
      const messageIds = Array.from(unreadMessages);
      onMarkAsRead(messageIds);
      setUnreadMessages(new Set());
    }, READ_RECEIPT_DEBOUNCE_MS);

    return () => clearTimeout(timer);
  }, [unreadMessages, onMarkAsRead]);

  return (
    <div
      ref={containerRef}
      onScroll={handleScroll}
      className="flex-1 overflow-y-auto smooth-scroll hide-scrollbar px-4 py-3 bg-white"
    >
      {messages.map((message, index) => (
        <MessageBubble
          key={message.id}
          message={message}
          season={season}
          showSender={shouldShowSender(message, index)}
          showTimestamp={shouldShowTimestamp(message, index)}
          onVisible={handleMessageVisible}
        />
      ))}

      {aiTyping && <TypingIndicator season={season} />}

      {!isAtBottom && messages.length > 0 && (
        <button
          onClick={() => scrollToBottom(containerRef.current)}
          className="fixed bottom-24 right-4 w-11 h-11 rounded-full bg-white shadow-elevated flex items-center justify-center text-primary-coral transition-all active:scale-90 border border-neutral-200/60"
          aria-label="맨 아래로"
        >
          <ArrowDown size={20} strokeWidth={2.5} />
        </button>
      )}
    </div>
  );
}
