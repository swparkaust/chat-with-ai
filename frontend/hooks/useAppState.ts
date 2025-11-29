import { useState, useEffect } from "react";
import { subscribeToChannel, unsubscribeFromChannel } from "@/lib/cable";
import { apiClient } from "@/lib/api";
import { logger } from "@/lib/logger";
import type { AppState, AppStateChannelMessage } from "@/types";
import type { Subscription } from "@rails/actioncable";

export function useAppState() {
  const [appState, setAppState] = useState<AppState | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let subscription: Subscription | null = null;

    const initialize = async () => {
      try {
        setLoading(true);
        setError(null);

        const response = await apiClient.getAppState();
        if (response.data) {
          setAppState(response.data);
        }

        const deviceId = apiClient.getDeviceId();
        if (deviceId) {
          subscription = subscribeToChannel(
            deviceId,
            "AppStateChannel",
            {},
            {
              received: (data: unknown) => {
                handleAppStateMessage(data as AppStateChannelMessage);
              },
            }
          );
        }
      } catch (err) {
        const message = (err as Error)?.message ?? "앱 상태를 불러올 수 없습니다";
        setError(message);
        logger.error("App state error:", err);
      } finally {
        setLoading(false);
      }
    };

    initialize();

    return () => {
      if (subscription) {
        unsubscribeFromChannel(subscription);
      }
    };
  }, []);

  const validateAppStateData = (
    data: AppStateChannelMessage
  ): { version: string; season_number: number; active_users: number } | null => {
    if (
      typeof data.version === "string" &&
      typeof data.season_number === "number" &&
      typeof data.active_users === "number"
    ) {
      return {
        version: data.version,
        season_number: data.season_number,
        active_users: data.active_users,
      };
    }
    logger.error("Invalid app state data received:", data);
    return null;
  };

  const validateActiveUsersCount = (count: unknown): number | null => {
    if (typeof count === "number" && count >= 0) {
      return count;
    }
    logger.error("Invalid active users count received:", count);
    return null;
  };

  const handleAppStateMessage = (data: AppStateChannelMessage) => {
    switch (data.type) {
      case "initial_state":
      case "state_update":
        const validated = validateAppStateData(data);
        if (validated) {
          setAppState({
            version: validated.version,
            season_number: validated.season_number,
            active_users: validated.active_users,
            total_users: 0,
            has_active_season: true,
          });
        }
        break;

      case "active_users_update":
        const validCount = validateActiveUsersCount(data.count);
        if (validCount !== null) {
          setAppState((prev) =>
            prev ? { ...prev, active_users: validCount } : prev
          );
        }
        break;

      case "season_change":
      case "season_rotated":
        // Reload the page on season change to reset everything
        if (typeof window !== "undefined") {
          window.location.reload();
        }
        break;
    }
  };

  return {
    appState,
    loading,
    error,
  };
}
