"use client";

import { useEffect, useState } from "react";
import { Smartphone } from "lucide-react";
import PromptBanner from "@/components/Common/PromptBanner";
import { usePWAInstall } from "@/hooks/usePWAInstall";
import {
  deferInstallAsk,
  isInstallAskDeferred,
  isPromptDismissed,
  isPushSupported,
} from "@/lib/utils";
import {
  INSTALL_PROMPT_DISMISSED_KEY,
  NOTIFICATION_PROMPT_DISMISSED_KEY,
} from "@/lib/constants";

// The two ambient banners must never stack: the notification ask (the
// retention lever) gets the session, and install waits for a LATER visit.
// App Router remounts this component on every page navigation, so per-mount
// state can't carry "this session is spoken for" — the sessionStorage flag
// does, written whenever the gate sees the ask unsettled (and by
// onboarding's install-skip). On iOS Safari, push is unsupported outside
// the installed app — the ask counts as settled and install correctly
// leads.
function notificationAskSettled(): boolean {
  if (!isPushSupported()) return true;
  return (
    Notification.permission !== "default" ||
    isPromptDismissed(NOTIFICATION_PROMPT_DISMISSED_KEY)
  );
}

export default function InstallPrompt() {
  const { installMethod, promptInstall } = usePWAInstall();
  const [canShow, setCanShow] = useState(false);

  // Effect, not state initializer: the predicate touches browser globals,
  // and both server and first client render must agree on null
  useEffect(() => {
    const settled = notificationAskSettled();
    if (!settled) {
      deferInstallAsk();
    }
    setCanShow(settled && !isInstallAskDeferred());
  }, []);

  if (!canShow) return null;

  if (installMethod === "manual") {
    return (
      <PromptBanner
        icon={<Smartphone size={20} className="text-primary-coral" strokeWidth={2} />}
        title="홈 화면에 추가"
        description="브라우저 하단의 공유 버튼을 누른 뒤 '홈 화면에 추가'를 선택하면 앱처럼 사용할 수 있어요"
        storageKey={INSTALL_PROMPT_DISMISSED_KEY}
        delayMs={5000}
        available
        dismissLabel="확인"
      />
    );
  }

  return (
    <PromptBanner
      icon={<Smartphone size={20} className="text-primary-coral" strokeWidth={2} />}
      title="홈 화면에 추가"
      description="앱처럼 빠르고 편리하게 사용하세요"
      storageKey={INSTALL_PROMPT_DISMISSED_KEY}
      delayMs={5000}
      available={installMethod === "prompt"}
      acceptLabel="설치하기"
      dismissLabel="나중에"
      onAccept={promptInstall}
    />
  );
}
