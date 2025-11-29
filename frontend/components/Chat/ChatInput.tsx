"use client";

import { useState, useRef, useEffect } from "react";
import { Send } from "lucide-react";
import { vibrate } from "@/lib/utils";
import { TYPING_TIMEOUT_MS } from "@/lib/constants";
import { logger } from "@/lib/logger";

interface ChatInputProps {
  onSend: (content: string) => Promise<void>;
  onTyping: (typing: boolean) => void;
  disabled?: boolean;
}

export default function ChatInput({
  onSend,
  onTyping,
  disabled = false,
}: ChatInputProps) {
  const [content, setContent] = useState("");
  const [sending, setSending] = useState(false);
  const inputRef = useRef<HTMLTextAreaElement>(null);
  const typingTimeoutRef = useRef<NodeJS.Timeout | null>(null);

  useEffect(() => {
    const textarea = inputRef.current;
    if (!textarea) return;

    textarea.style.height = "auto";
    textarea.style.height = `${Math.min(textarea.scrollHeight, 120)}px`;
  }, [content]);

  useEffect(() => {
    return () => {
      if (typingTimeoutRef.current) {
        clearTimeout(typingTimeoutRef.current);
      }
    };
  }, []);

  const handleChange = (e: React.ChangeEvent<HTMLTextAreaElement>) => {
    setContent(e.target.value);

    onTyping(true);

    if (typingTimeoutRef.current) {
      clearTimeout(typingTimeoutRef.current);
    }

    typingTimeoutRef.current = setTimeout(() => {
      onTyping(false);
    }, TYPING_TIMEOUT_MS);
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    if (!content.trim() || sending || disabled) return;

    try {
      setSending(true);
      onTyping(false);

      if (typingTimeoutRef.current) {
        clearTimeout(typingTimeoutRef.current);
      }

      await onSend(content.trim());
      setContent("");
      vibrate(10);
    } catch (err) {
      logger.error("Failed to send message:", err);
      vibrate([10, 50, 10]);
    } finally {
      setSending(false);
      inputRef.current?.focus();
    }
  };

  const handleKeyDown = (e: React.KeyboardEvent<HTMLTextAreaElement>) => {
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      handleSubmit(e);
    }
  };

  return (
    <form
      onSubmit={handleSubmit}
      className="safe-area-bottom bg-white/95 backdrop-blur-xl border-t border-neutral-200/60 px-4 py-2.5"
    >
      <div className="flex items-end gap-2">
        <div className="flex-1 relative">
          <textarea
            ref={inputRef}
            value={content}
            onChange={handleChange}
            onKeyDown={handleKeyDown}
            placeholder="메시지"
            disabled={disabled || sending}
            rows={1}
            className="w-full resize-none max-h-[120px] overflow-y-auto hide-scrollbar disabled:opacity-50 text-neutral-900 placeholder:text-neutral-400 bg-neutral-100 rounded-[20px] px-4 py-2.5 text-[15px] leading-[20px] outline-none focus:bg-neutral-50 transition-colors border border-transparent focus:border-neutral-200"
            style={{ minHeight: "40px" }}
          />
        </div>

        <button
          type="submit"
          disabled={!content.trim() || sending || disabled}
          className={`flex-shrink-0 w-9 h-9 mb-2 rounded-full flex items-center justify-center transition-all active:scale-90 ${
            content.trim() && !sending && !disabled
              ? "bg-primary-coral text-white"
              : "bg-neutral-200 text-neutral-400 cursor-not-allowed"
          }`}
          aria-label="전송"
        >
          {sending ? (
            <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin"></div>
          ) : (
            <Send size={16} />
          )}
        </button>
      </div>
    </form>
  );
}
