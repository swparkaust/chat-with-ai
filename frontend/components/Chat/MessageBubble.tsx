"use client";

import { formatMessageTime } from "@/lib/utils";
import { useIntersectionObserver } from "@/hooks/useIntersectionObserver";
import { useVisibility } from "@/hooks/useVisibility";
import { useEffect } from "react";
import ProfilePicture from "@/components/Common/ProfilePicture";
import type { Message, Season } from "@/types";

interface MessageBubbleProps {
  message: Message;
  season?: Season;
  showSender: boolean;
  showTimestamp: boolean;
  onVisible?: (messageId: number) => void;
}

export default function MessageBubble({
  message,
  season,
  showSender,
  showTimestamp,
  onVisible,
}: MessageBubbleProps) {
  const isUser = message.sender_type === "user";
  const isVisible = useVisibility();
  const [ref, isInViewport] = useIntersectionObserver({
    threshold: 0.5,
    freezeOnceVisible: false,
  });

  useEffect(() => {
    if (
      isInViewport &&
      isVisible &&
      !message.read_at &&
      message.sender_type === "ai" &&
      onVisible
    ) {
      onVisible(message.id);
    }
  }, [isInViewport, isVisible, message.id, message.read_at, message.sender_type, onVisible]);

  return (
    <div
      ref={ref}
      className={`flex mb-1.5 animate-scale-in ${isUser ? "justify-end" : "justify-start"}`}
    >
      {!isUser && (
        <div className="flex-shrink-0 w-8 h-8 mr-2">
          {showSender && (
            <ProfilePicture
              imageUrl={season?.profile_picture}
              size="xs"
              alt={season?.full_name ?? ""}
            />
          )}
        </div>
      )}

      <div className="flex flex-col max-w-[75%]">
        {!isUser && showSender && season && (
          <span className="text-[12px] text-neutral-700 font-medium mb-1 px-1">
            {season.full_name}
          </span>
        )}

        <div
          className={`px-3.5 py-2.5 rounded-2xl break-words text-[15px] leading-[20px] shadow-sm ${
            isUser
              ? "bg-primary-coral text-white ml-auto"
              : "bg-neutral-100 text-neutral-900 mr-auto"
          }`}
          style={{
            wordBreak: "break-word",
            overflowWrap: "break-word",
          }}
        >
          {message.content}
        </div>

        <div
          className={`flex items-center gap-1.5 mt-0.5 px-1 ${
            isUser ? "justify-end" : "justify-start"
          }`}
        >
          {showTimestamp && (
            <span className="text-[11px] text-neutral-500">{formatMessageTime(message.created_at)}</span>
          )}
          {!message.read_at && (
            <span className="text-[11px] text-primary-red font-semibold">1</span>
          )}
        </div>
      </div>
    </div>
  );
}
