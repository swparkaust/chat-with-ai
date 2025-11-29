import { useState, useEffect, useCallback, useRef, useMemo } from "react";
import { subscribeToChannel, unsubscribeFromChannel } from "@/lib/cable";
import { apiClient } from "@/lib/api";
import { debounce } from "@/lib/utils";
import { logger } from "@/lib/logger";
import { authEvents } from "@/lib/events";
import { useVisibility } from "@/hooks/useVisibility";
import type {
  Conversation,
  Message,
  ConversationChannelMessage,
} from "@/types";
import type { Subscription } from "@rails/actioncable";

export function useConversation(conversationId?: number) {
  const [conversation, setConversation] = useState<Conversation | null>(null);
  const [messages, setMessages] = useState<Message[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [aiTyping, setAiTyping] = useState(false);
  const [hasMoreMessages, setHasMoreMessages] = useState(true);

  const subscriptionRef = useRef<Subscription | null>(null);
  const conversationIdRef = useRef<number | null>(null);
  const mountedRef = useRef(true);
  const isVisible = useVisibility();

  useEffect(() => {
    initialize();

    return () => {
      mountedRef.current = false;
      if (subscriptionRef.current) {
        unsubscribeFromChannel(subscriptionRef.current);
      }
    };
  }, [conversationId]);

  useEffect(() => {
    if (conversationIdRef.current) {
      apiClient.updateUserFocus(conversationIdRef.current, isVisible).catch((err) => {
        logger.error("Failed to update focus status:", err);
      });
    }
  }, [isVisible]);

  const initialize = async () => {
    try {
      setLoading(true);
      setError(null);

      // Wait for authentication to complete if device_id not available yet
      if (!apiClient.getDeviceId()) {
        await Promise.race([
          authEvents.once('auth:initialized'),
          authEvents.once('auth:failed').then(() => {
            throw new Error("인증이 완료되지 않았습니다");
          }),
        ]);
      }

      const convResponse = conversationId
        ? await apiClient.getConversation(conversationId)
        : await apiClient.getCurrentConversation();
      if (!convResponse.data?.conversation) {
        throw new Error("대화를 불러올 수 없습니다");
      }

      const conv = convResponse.data.conversation;
      setConversation(conv);
      conversationIdRef.current = conv.id;

      const messagesResponse = await apiClient.getMessages(conv.id, 1, 50);
      if (messagesResponse.messages) {
        setMessages(messagesResponse.messages); // Already in ascending order
        setHasMoreMessages(messagesResponse.has_more ?? false);
      }

      const deviceId = apiClient.getDeviceId();
      if (deviceId) {
        subscriptionRef.current = subscribeToChannel(
          deviceId,
          "ConversationChannel",
          { conversation_id: conv.id },
          {
            connected: () => {
              if (conversationIdRef.current) {
                apiClient.updateUserFocus(conversationIdRef.current, !document.hidden).catch((err) => {
                  logger.error("Failed to update initial focus status:", err);
                });
              }
            },
            received: (data: unknown) => {
              handleConversationMessage(data as ConversationChannelMessage);
            },
          }
        );
      }
    } catch (err) {
      const message = (err as Error)?.message ?? "대화를 불러올 수 없습니다";
      setError(message);
      logger.error("Conversation error:", err);
    } finally {
      setLoading(false);
    }
  };

  const handleConversationMessage = (data: ConversationChannelMessage) => {
    switch (data.type) {
      case "message":
        if (data.message) {
          const newMessage = data.message;
          setMessages((prev) => {
            // Prevent duplicates (can happen due to React Strict Mode double-mounting)
            if (prev.some(msg => msg.id === newMessage.id)) {
              return prev;
            }
            return [...prev, newMessage];
          });
          setAiTyping(false);
        }
        break;

      case "typing":
        if (data.sender_type === "ai") {
          setAiTyping(data.is_typing ?? false);
        }
        break;

      case "read_receipt":
        if (data.message_id) {
          setMessages((prev) =>
            prev.map((msg) =>
              msg.id === data.message_id
                ? { ...msg, read_at: new Date().toISOString() }
                : msg
            )
          );
        }
        break;
    }
  };

  const sendMessage = async (content: string): Promise<Message | null> => {
    if (!conversation) return null;

    try {
      const response = await apiClient.sendMessage(conversation.id, content);
      if (response.data) {
        return response.data.message;
      }
      return null;
    } catch (err) {
      const message = (err as Error)?.message ?? "메시지 전송에 실패했습니다";
      setError(message);
      throw err;
    }
  };

  const setTyping = useCallback(
    async (typing: boolean) => {
      if (!mountedRef.current || !conversationIdRef.current) return;

      try {
        await apiClient.updateUserState(conversationIdRef.current, typing);
      } catch (err) {
        if (!mountedRef.current) return;
        logger.error("Failed to update typing status:", err);
      }
    },
    []
  );

  const debouncedSetTyping = useMemo(
    () => debounce(setTyping, 300),
    [setTyping]
  );

  const markAsRead = async (messageIds: number[]) => {
    if (!conversation || messageIds.length === 0) return;

    try {
      await apiClient.markMessagesAsRead(conversation.id, messageIds);
    } catch (err) {
      logger.error("Failed to mark messages as read:", err);
    }
  };

  const loadMoreMessages = async () => {
    if (!conversation || !hasMoreMessages || loading) return;

    try {
      const oldestMessageId = messages.length > 0 ? messages[0].id : undefined;
      const response = await apiClient.getMessages(
        conversation.id,
        undefined,
        50,
        oldestMessageId
      );

      if (response.messages) {
        setMessages((prev) => [...response.messages, ...prev]);
        setHasMoreMessages(response.has_more ?? false);
      }
    } catch (err) {
      logger.error("Failed to load more messages:", err);
    }
  };

  return {
    conversation,
    messages,
    loading,
    error,
    aiTyping,
    hasMoreMessages,
    sendMessage,
    setTyping: debouncedSetTyping,
    markAsRead,
    loadMoreMessages,
  };
}
