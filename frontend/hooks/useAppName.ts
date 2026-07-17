import { useEffect, useState } from "react";
import { apiClient } from "@/lib/api";
import { addKoreanParticleWa } from "@/lib/utils";
import { logger } from "@/lib/logger";
import { authEvents } from "@/lib/events";
import type { Profile } from "@/types";

const DEFAULT_APP_NAME = "○○와 채팅하기";

let cachedProfile: Profile | null = null;
let profilePromise: Promise<Profile | null> | null = null;

async function fetchAiProfile(): Promise<Profile | null> {
  if (!apiClient.getDeviceId()) {
    await authEvents.once("auth:initialized");
  }

  try {
    const response = await apiClient.getAiProfile();
    return response.data?.profile ?? null;
  } catch (err) {
    if (err instanceof Error && !err.message.includes("Unauthorized")) {
      logger.error("Failed to load AI profile for app name:", err);
    }
    return null;
  }
}

export function useAppName() {
  const [aiProfile, setAiProfile] = useState<Profile | null>(cachedProfile);

  useEffect(() => {
    if (cachedProfile) return;

    let active = true;

    profilePromise ??= fetchAiProfile();
    profilePromise.then((profile) => {
      if (profile) {
        cachedProfile = profile;
        if (active) {
          setAiProfile(profile);
        }
      } else {
        profilePromise = null;
      }
    });

    return () => {
      active = false;
    };
  }, []);

  const appName = aiProfile?.first_name
    ? `${addKoreanParticleWa(aiProfile.first_name)} 채팅하기`
    : DEFAULT_APP_NAME;

  return { appName };
}
