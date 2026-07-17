import { useState, useEffect, useCallback, useRef, useMemo } from "react";
import { subscribeToChannel, unsubscribeFromChannel } from "@/lib/cable";
import { apiClient } from "@/lib/api";
import { debounce, vibrate } from "@/lib/utils";
import { MESSAGE_PAGE_SIZE } from "@/lib/constants";
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
  const [offlineNotice, setOfflineNotice] = useState(false);
  const [retryNonce, setRetryNonce] = useState(0);
  const offlineNoticeTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const subscriptionRef = useRef<Subscription | null>(null);
  const conversationIdRef = useRef<number | null>(null);
  const mountedRef = useRef(true);
  const loadingMoreRef = useRef(false);
  // Each effect run is a new generation; async work from an older run must
  // stop writing state or subscribing once a newer run exists
  const initGenRef = useRef(0);
  const isVisible = useVisibility();

  useEffect(() => {
    // Cleanup flips mountedRef off, so a re-run (conversation change or
    // retry) must flip it back on before initializing
    mountedRef.current = true;
    initialize();

    return () => {
      initGenRef.current += 1;
      mountedRef.current = false;
      // Nulling conversationIdRef blocks late callbacks (pending debounced
      // setTyping, focus/scroll writes) from targeting the old conversation
      conversationIdRef.current = null;
      debouncedSetTyping.cancel();
      if (subscriptionRef.current) {
        unsubscribeFromChannel(subscriptionRef.current);
        subscriptionRef.current = null;
      }
      if (offlineNoticeTimerRef.current) {
        clearTimeout(offlineNoticeTimerRef.current);
      }
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [conversationId, retryNonce]);

  useEffect(() => {
    if (conversationIdRef.current) {
      apiClient.updateUserState(conversationIdRef.current, { focused: isVisible }).catch((err) => {
        logger.error("Failed to update focus status:", err);
      });
    }
  }, [isVisible]);

  const initialize = async () => {
    const gen = initGenRef.current;
    try {
      setLoading(true);
      setError(null);
      setOfflineNotice(false);
      // Reset per-conversation state so a retry or conversation switch never
      // renders the previous session's data
      setConversation(null);
      setMessages([]);
      setAiTyping(false);
      setHasMoreMessages(true);

      // Wait for authentication to complete if device_id not available yet.
      // Explicit on/off pair rather than racing two once() promises: once()
      // only self-removes when its own event fires, so the race loser would
      // leak a listener per run.
      if (!apiClient.getDeviceId()) {
        await new Promise<void>((resolve, reject) => {
          const cleanup = () => {
            authEvents.off("auth:initialized", onInit);
            authEvents.off("auth:failed", onFail);
          };
          const onInit = () => {
            cleanup();
            resolve();
          };
          const onFail = () => {
            cleanup();
            reject(new Error("인증이 완료되지 않았습니다"));
          };
          authEvents.on("auth:initialized", onInit);
          authEvents.on("auth:failed", onFail);
        });
      }
      if (gen !== initGenRef.current) return;

      const convResponse = conversationId
        ? await apiClient.getConversation(conversationId)
        : await apiClient.getCurrentConversation();
      if (gen !== initGenRef.current) return;
      if (!convResponse.data?.conversation) {
        throw new Error("대화를 불러올 수 없습니다");
      }

      const conv = convResponse.data.conversation;
      setConversation(conv);

      // Persist focus and reset any stale scroll position from a previous
      // session before messages render, so the first read receipts aren't
      // dropped by the server's focus gate and notifications aren't rung
      // for an at-bottom, focused user. Fetched concurrently with messages:
      // rendering (and thus every later user-state write) waits on both.
      const focusedAtInit = !document.hidden;
      const [, messagesResponse] = await Promise.all([
        apiClient
          .updateUserState(conv.id, { focused: focusedAtInit, scroll_position: 0 })
          .catch((err) => {
            logger.error("Failed to set initial user state:", err);
          }),
        apiClient.getMessages(conv.id, MESSAGE_PAGE_SIZE),
      ]);
      if (gen !== initGenRef.current) return;
      // Armed only after the initial focus/scroll write settles, so a
      // visibility flip during that write can't race it with a second PATCH
      conversationIdRef.current = conv.id;
      // A flip during that write was dropped (ref was still null) —
      // reconcile so the server isn't stuck with the pre-flip direction.
      // Fire-and-forget: a rare reorder against a subsequent flip's PATCH is
      // accepted — the connected-callback re-send corrects it in seconds.
      if (!document.hidden !== focusedAtInit) {
        apiClient.updateUserState(conv.id, { focused: !document.hidden }).catch((err) => {
          logger.error("Failed to reconcile focus state:", err);
        });
      }
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
                apiClient.updateUserState(conversationIdRef.current, { focused: !document.hidden }).catch((err) => {
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
      // A stale run's failure belongs to a session that no longer exists
      if (gen !== initGenRef.current) return;
      const message = (err as Error)?.message ?? "대화를 불러올 수 없습니다";
      setError(message);
      logger.error("Conversation error:", err);
    } finally {
      if (gen === initGenRef.current) {
        setLoading(false);
      }
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
        if (data.message_ids?.length) {
          const readIds = new Set(data.message_ids);
          const readAt = data.read_at ?? new Date().toISOString();
          setMessages((prev) =>
            prev.map((msg) =>
              readIds.has(msg.id) ? { ...msg, read_at: readAt } : msg
            )
          );
        }
        break;

      case "notification_bell":
        if (!document.hidden) {
          vibrate([10, 50, 10]);
        }
        break;
    }
  };

  // Send failures deliberately do NOT set the page-level error — that would
  // unmount the whole chat (draft included) into a dead-end card. They
  // propagate to ChatInput's catch, which surfaces them inline with the
  // draft preserved.
  const sendMessage = async (content: string): Promise<Message | null> => {
    // Throw, never resolve: a null resolution here would read as success to
    // ChatInput, which clears the draft. The message text is diagnostic only
    // — ChatInput deliberately shows generic copy for non-ApiError throws.
    if (!conversation) {
      throw new Error("대화가 아직 준비되지 않았습니다");
    }

    const response = await apiClient.sendMessage(conversation.id, content);
    if (response.data) {
      return response.data.message;
    }
    if (response.queued) {
      logger.info("Offline - message queued, will send when back online");
      setOfflineNotice(true);
      if (offlineNoticeTimerRef.current) {
        clearTimeout(offlineNoticeTimerRef.current);
      }
      offlineNoticeTimerRef.current = setTimeout(() => {
        setOfflineNotice(false);
      }, 5000);
    }
    return null;
  };

  const setTyping = useCallback(
    async (typing: boolean) => {
      if (!mountedRef.current || !conversationIdRef.current) return;

      try {
        await apiClient.updateUserState(conversationIdRef.current, { typing });
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

  const updateScrollPosition = useCallback((scrollPosition: number) => {
    if (!conversationIdRef.current) return;

    apiClient
      .updateUserState(conversationIdRef.current, { scroll_position: scrollPosition })
      .catch((err) => {
        logger.error("Failed to update scroll position:", err);
      });
  }, []);

  const markAsRead = useCallback(async (messageIds: number[]) => {
    if (!conversationIdRef.current || messageIds.length === 0) return;

    try {
      await apiClient.markMessagesAsRead(conversationIdRef.current, messageIds);
    } catch (err) {
      logger.error("Failed to mark messages as read:", err);
    }
  }, []);

  const loadMoreMessages = async () => {
    if (!conversation || !hasMoreMessages || loading || loadingMoreRef.current) return;

    const gen = initGenRef.current;
    loadingMoreRef.current = true;
    try {
      const oldestMessageId = messages.length > 0 ? messages[0].id : undefined;
      const response = await apiClient.getMessages(
        conversation.id,
        MESSAGE_PAGE_SIZE,
        oldestMessageId
      );
      if (gen !== initGenRef.current) return;

      if (response.messages) {
        setMessages((prev) => [...response.messages, ...prev]);
        setHasMoreMessages(response.has_more ?? false);
      }
    } catch (err) {
      logger.error("Failed to load more messages:", err);
    } finally {
      loadingMoreRef.current = false;
    }
  };

  return {
    conversation,
    messages,
    loading,
    error,
    aiTyping,
    hasMoreMessages,
    offlineNotice,
    retry: () => setRetryNonce((n) => n + 1),
    sendMessage,
    setTyping: debouncedSetTyping,
    markAsRead,
    loadMoreMessages,
    updateScrollPosition,
  };
}
