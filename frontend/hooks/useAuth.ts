import { useState, useEffect, useRef } from "react";
import { apiClient } from "@/lib/api";
import { generateDeviceId } from "@/lib/utils";
import { logger } from "@/lib/logger";
import { authEvents } from "@/lib/events";
import type { User } from "@/types";

export function useAuth() {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const authenticatingRef = useRef(false);
  const mountedRef = useRef(true);

  useEffect(() => {
    mountedRef.current = true;
    authenticate();

    return () => {
      mountedRef.current = false;
    };
  }, []);

  const authenticate = async () => {
    // Prevent concurrent authentication (e.g., from React Strict Mode double-mounting)
    if (authenticatingRef.current) {
      return;
    }

    authenticatingRef.current = true;

    try {
      setLoading(true);
      setError(null);

      let deviceId = apiClient.getDeviceId();

      if (deviceId) {
        try {
          const response = await apiClient.verifyAuth();
          if (response.data) {
            setUser(response.data.user);
            authEvents.emit('auth:initialized', {
              user: response.data.user,
              deviceId: deviceId
            });
            return;
          }
        } catch (err) {
          // Verification failed (expected for new users), continue to authenticate
          // Don't log this as it's a normal part of the auth flow
        }
      }

      if (!deviceId) {
        deviceId = generateDeviceId();
        apiClient.setDeviceId(deviceId);
      }

      const response = await apiClient.authenticate();
      if (response.data) {
        setUser(response.data.user);
        authEvents.emit('auth:initialized', {
          user: response.data.user,
          deviceId: deviceId
        });
      } else if (!response.data) {
        throw new Error("Authentication failed");
      }
    } catch (err) {
      const message = (err as Error)?.message ?? "인증에 실패했습니다";
      setError(message);
      authEvents.emit('auth:failed', { error: message });
      logger.error("Authentication error:", err);
    } finally {
      setLoading(false);
      authenticatingRef.current = false;
    }
  };

  const updateUser = async (data: Partial<User>) => {
    try {
      const response = await apiClient.updateUser(data);
      if (response.data) {
        setUser(response.data.user);
        authEvents.emit('auth:updated', { user: response.data.user });
      }
    } catch (err) {
      const message = (err as Error)?.message ?? "사용자 정보 업데이트 실패";
      setError(message);
      throw err;
    }
  };

  return {
    user,
    loading,
    error,
    authenticate,
    updateUser,
  };
}
