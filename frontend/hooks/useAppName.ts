import { useEffect, useState } from "react";
import { apiClient } from "@/lib/api";
import { addKoreanParticleWa } from "@/lib/utils";
import { logger } from "@/lib/logger";
import { authEvents } from "@/lib/events";
import type { Profile } from "@/types";

const DEFAULT_APP_NAME = "○○와 채팅하기";

export function useAppName() {
  const [aiProfile, setAiProfile] = useState<Profile | null>(null);

  useEffect(() => {
    const loadAiProfile = async () => {
      if (!apiClient.getDeviceId()) {
        try {
          await authEvents.once('auth:initialized');
        } catch {
          return;
        }
      }

      try {
        const response = await apiClient.getAiProfile();
        if (response.data?.profile) {
          setAiProfile(response.data.profile);
        }
      } catch (err) {
        if (err instanceof Error && !err.message.includes("Unauthorized")) {
          logger.error("Failed to load AI profile for app name:", err);
        }
      }
    };

    loadAiProfile();

    const handleAuth = () => {
      loadAiProfile();
    };

    authEvents.on('auth:initialized', handleAuth);

    return () => {
      authEvents.off('auth:initialized', handleAuth);
    };
  }, []);

  const appName = aiProfile?.first_name
    ? `${addKoreanParticleWa(aiProfile.first_name)} 채팅하기`
    : DEFAULT_APP_NAME;

  return { appName };
}
