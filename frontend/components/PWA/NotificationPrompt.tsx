"use client";

import { Bell } from "lucide-react";
import PromptBanner from "@/components/Common/PromptBanner";
import { usePushNotifications } from "@/hooks/usePushNotifications";
import { NOTIFICATION_PROMPT_DISMISSED_KEY } from "@/lib/constants";

export default function NotificationPrompt() {
  const { permission, isSupported, subscribe, isSubscribed } =
    usePushNotifications();

  return (
    <PromptBanner
      icon={<Bell size={20} className="text-primary-coral" strokeWidth={2} />}
      title="알림 받기"
      description="새 메시지가 도착하면 알려드릴게요"
      storageKey={NOTIFICATION_PROMPT_DISMISSED_KEY}
      delayMs={3000}
      available={isSupported && permission === "default" && !isSubscribed}
      acceptLabel="알림 켜기"
      dismissLabel="나중에"
      onAccept={subscribe}
    />
  );
}
