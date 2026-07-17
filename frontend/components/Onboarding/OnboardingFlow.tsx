"use client";

import { useState, useRef } from "react";
import { Bell, Smartphone, CheckCircle, Share, SquarePlus } from "lucide-react";
import { logger } from "@/lib/logger";
import { usePushNotifications } from "@/hooks/usePushNotifications";
import { usePWAInstall } from "@/hooks/usePWAInstall";
import { useAppName } from "@/hooks/useAppName";
import { useDocumentTitle } from "@/hooks/useDocumentTitle";
import { useProfileEditor } from "@/hooks/useProfileEditor";
import { useClosingTransition } from "@/hooks/useClosingTransition";
import ProfilePicture from "@/components/Common/ProfilePicture";
import {
  adoptDeviceIdentity,
  claimErrorMessage,
  isCompleteLinkCode,
} from "@/lib/deviceLink";
import { INSTALL_PROMPT_DISMISSED_KEY } from "@/lib/constants";
import { deferInstallAsk, dismissPrompt } from "@/lib/utils";

interface OnboardingFlowProps {
  onComplete: () => void;
}

type Step = "profile" | "link" | "notifications" | "install" | "done";

export default function OnboardingFlow({ onComplete }: OnboardingFlowProps) {
  const [step, setStep] = useState<Step>("profile");
  const [name, setName] = useState("");
  const [statusMessage, setStatusMessage] = useState("");
  const [linkCode, setLinkCode] = useState("");
  const [linkError, setLinkError] = useState<string | null>(null);
  const [claiming, setClaiming] = useState(false);
  const { previewUrl, uploadError, saveError, saving, handleFileChange, saveProfile } =
    useProfileEditor();
  const { isClosing, close } = useClosingTransition();
  const { subscribe, isSupported: notificationsSupported } = usePushNotifications();
  const { promptInstall, installMethod } = usePWAInstall();
  const { appName } = useAppName();
  useDocumentTitle();

  const handleProfileSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    if (!name.trim()) return;

    try {
      await saveProfile({ name, status_message: statusMessage });
      // iOS in-browser has no push support (Safari only exposes it to
      // installed PWAs), so the notifications step would render nothing —
      // route past it; the NotificationPrompt banner offers push later,
      // once the app runs standalone
      if (notificationsSupported) {
        setStep("notifications");
      } else {
        goToInstallOrDone();
      }
    } catch (err) {
      logger.error("Failed to save profile:", err);
    }
  };

  const installOrDone: Step = installMethod ? "install" : "done";

  const goToInstallOrDone = () => {
    setStep(installOrDone);
  };

  // Per-action pending gates: the ref blocks a same-frame second tap (state
  // would be stale in its closure), the state drives the button's disabled
  // styling. Skip buttons stay live — the native dialogs can pend unboundedly
  // — which is why the post-await advances below are step-conditional: a
  // late-resolving dialog must not yank a user who already skipped ahead.
  const notifyPendingRef = useRef(false);
  const [notifyPending, setNotifyPending] = useState(false);
  const installPendingRef = useRef(false);
  const [installPending, setInstallPending] = useState(false);

  const handleEnableNotifications = async () => {
    if (notifyPendingRef.current) return;

    notifyPendingRef.current = true;
    setNotifyPending(true);
    try {
      await subscribe();
    } finally {
      notifyPendingRef.current = false;
      setNotifyPending(false);
    }
    // Move forward even if user declined
    setStep((s) => (s === "notifications" ? installOrDone : s));
  };

  const handleAcknowledgeManualInstall = () => {
    // The user just read the share-sheet walkthrough — suppress the ambient
    // InstallPrompt banner, which would otherwise repeat the identical
    // instructions seconds after onboarding completes
    dismissPrompt(INSTALL_PROMPT_DISMISSED_KEY);
    setStep("done");
  };

  const handleInstallApp = async () => {
    if (installPendingRef.current) return;

    installPendingRef.current = true;
    setInstallPending(true);
    try {
      await promptInstall();
    } finally {
      installPendingRef.current = false;
      setInstallPending(false);
    }
    setStep((s) => (s === "install" ? "done" : s));
  };

  const handleSkipInstall = () => {
    // Session-scoped (unlike the manual path's persistent dismissal): the
    // user declined the native prompt seconds ago — the ambient banner may
    // re-offer on a later visit, but not this session
    deferInstallAsk();
    setStep("done");
  };

  const handleFinish = () => {
    close(onComplete);
  };

  const handleClaimLink = async (e: React.FormEvent) => {
    e.preventDefault();
    setClaiming(true);
    setLinkError(null);

    try {
      await adoptDeviceIdentity(linkCode);
      // No setClaiming(false): adoption ends in a reload
    } catch (err) {
      logger.error("Failed to claim device link:", err);
      setLinkError(claimErrorMessage(err));
      setClaiming(false);
    }
  };

  return (
    <div className={`fixed inset-0 bg-gradient-to-b from-white to-neutral-50 z-50 flex items-center justify-center p-4 overflow-y-auto ${isClosing ? 'animate-modal-exit' : 'animate-modal-enter'}`}>
      <div className="w-full max-w-md">
        {step === "profile" && (
          <div className="space-y-6">
            <div className="text-center">
              <h1 className="text-3xl font-bold mb-2 text-neutral-900">{appName}에 오신 것을 환영합니다!</h1>
              <p className="text-neutral-500">먼저 프로필을 설정해주세요</p>
            </div>

            <form onSubmit={handleProfileSubmit} className="space-y-4">
              <div className="flex flex-col items-center">
                <ProfilePicture
                  imageUrl={previewUrl}
                  size="lg"
                  alt=""
                  className="shadow-elevated mb-3"
                />
                <label className="px-5 py-2.5 bg-white border border-neutral-200 rounded-full text-sm font-medium text-primary-coral cursor-pointer active:bg-neutral-50 transition-colors shadow-sm">
                  사진 선택
                  <input
                    type="file"
                    accept="image/*"
                    onChange={handleFileChange}
                    disabled={saving}
                    className="hidden"
                  />
                </label>
                {uploadError && (
                  <p className="mt-2 text-sm text-primary-red text-center px-4">
                    {uploadError}
                  </p>
                )}
              </div>

              <div className="bg-white rounded-2xl shadow-sm overflow-hidden">
                <div className="px-4 py-3.5 border-b border-neutral-100">
                  <label className="text-xs font-medium text-neutral-500 uppercase tracking-wide">
                    이름 <span className="text-primary-red">*</span>
                  </label>
                </div>
                <div className="px-4 py-3.5">
                  <input
                    type="text"
                    value={name}
                    onChange={(e) => setName(e.target.value)}
                    disabled={saving}
                    className="w-full text-base text-neutral-900 font-medium bg-transparent outline-none placeholder:text-neutral-400 disabled:opacity-50"
                    placeholder="이름을 입력하세요"
                    required
                  />
                </div>
              </div>

              <div className="bg-white rounded-2xl shadow-sm overflow-hidden">
                <div className="px-4 py-3.5 border-b border-neutral-100">
                  <label className="text-xs font-medium text-neutral-500 uppercase tracking-wide">
                    상태 메시지
                  </label>
                </div>
                <div className="px-4 py-3.5">
                  <input
                    type="text"
                    value={statusMessage}
                    onChange={(e) => setStatusMessage(e.target.value)}
                    disabled={saving}
                    className="w-full text-base text-neutral-800 bg-transparent outline-none placeholder:text-neutral-400 disabled:opacity-50"
                    placeholder="상태 메시지를 입력하세요 (선택)"
                  />
                </div>
              </div>

              {saveError && (
                <p className="text-sm text-primary-red text-center px-4">
                  {saveError}
                </p>
              )}

              <button
                type="submit"
                disabled={!name.trim() || saving}
                className="w-full mt-2 px-6 py-3.5 bg-primary-coral text-white rounded-full font-semibold active:opacity-80 transition-opacity shadow-sm disabled:opacity-40"
              >
                {saving ? "저장 중..." : "다음"}
              </button>
            </form>

            <button
              type="button"
              onClick={() => setStep("link")}
              className="w-full text-center text-sm text-neutral-500 active:opacity-70 transition-opacity"
            >
              기존 기기에서 옮겨오셨나요?{" "}
              <span className="text-primary-coral font-medium">코드로 이어가기</span>
            </button>
          </div>
        )}

        {step === "link" && (
          <div className="space-y-6">
            <div className="text-center">
              <h1 className="text-3xl font-bold mb-2 text-neutral-900">기존 대화 이어가기</h1>
              <p className="text-neutral-500">
                기존 기기의 프로필 화면에서 발급한 코드를 입력하세요
              </p>
            </div>

            <form onSubmit={handleClaimLink} className="space-y-4">
              <div className="bg-white rounded-2xl shadow-sm px-4 py-3.5">
                <input
                  type="text"
                  value={linkCode}
                  onChange={(e) => setLinkCode(e.target.value.toUpperCase())}
                  disabled={claiming}
                  autoCapitalize="characters"
                  autoComplete="one-time-code"
                  maxLength={7}
                  className="w-full text-center text-2xl tracking-[0.3em] font-semibold text-neutral-900 bg-transparent outline-none placeholder:text-neutral-300 placeholder:tracking-normal disabled:opacity-50"
                  placeholder="ABC-123"
                />
              </div>

              {linkError && (
                <p className="text-sm text-primary-red text-center px-4">{linkError}</p>
              )}

              <button
                type="submit"
                disabled={claiming || !isCompleteLinkCode(linkCode)}
                className="w-full px-6 py-3.5 bg-primary-coral text-white rounded-full font-semibold active:opacity-80 transition-opacity shadow-sm disabled:opacity-40"
              >
                {claiming ? "확인 중..." : "이어가기"}
              </button>
            </form>

            <button
              type="button"
              onClick={() => setStep("profile")}
              disabled={claiming}
              className="w-full text-center text-sm text-neutral-500 active:opacity-70 transition-opacity disabled:opacity-40"
            >
              돌아가기
            </button>
          </div>
        )}

        {step === "notifications" && (
          <div className="space-y-6">
            <div className="text-center">
              <div className="w-24 h-24 mx-auto mb-4 rounded-full bg-primary-coral/10 flex items-center justify-center">
                <Bell size={48} className="text-primary-coral" strokeWidth={2} />
              </div>
              <h2 className="text-3xl font-bold mb-2 text-neutral-900">알림 받기</h2>
              <p className="text-neutral-500">새 메시지가 도착하면 알려드릴게요</p>
            </div>

            <div className="space-y-3">
              <button
                onClick={handleEnableNotifications}
                disabled={notifyPending}
                className="w-full px-6 py-3.5 bg-primary-coral text-white rounded-full font-semibold active:opacity-80 transition-opacity shadow-sm disabled:opacity-50"
              >
                알림 켜기
              </button>
              <button
                onClick={goToInstallOrDone}
                className="w-full px-6 py-3.5 bg-white border border-neutral-200 rounded-full font-medium text-neutral-700 active:bg-neutral-50 transition-colors shadow-sm"
              >
                나중에
              </button>
            </div>
          </div>
        )}

        {step === "install" && (
          <div className="space-y-6">
            <div className="text-center">
              <div className="w-24 h-24 mx-auto mb-4 rounded-full bg-primary-coral/10 flex items-center justify-center">
                <Smartphone size={48} className="text-primary-coral" strokeWidth={2} />
              </div>
              <h2 className="text-3xl font-bold mb-2 text-neutral-900">홈 화면에 추가</h2>
              <p className="text-neutral-500">앱처럼 빠르게 실행할 수 있어요</p>
            </div>

            {installMethod === "manual" ? (
              <div className="space-y-3">
                <div className="bg-neutral-100 rounded-2xl p-4 space-y-3">
                  <p className="flex items-center gap-3 text-sm text-neutral-700">
                    <Share size={20} className="flex-shrink-0 text-primary-coral" strokeWidth={2} />
                    1. 브라우저 하단의 공유 버튼을 누르세요
                  </p>
                  <p className="flex items-center gap-3 text-sm text-neutral-700">
                    <SquarePlus size={20} className="flex-shrink-0 text-primary-coral" strokeWidth={2} />
                    2. &apos;홈 화면에 추가&apos;를 선택하세요
                  </p>
                </div>
                <button
                  onClick={handleAcknowledgeManualInstall}
                  className="w-full px-6 py-3.5 bg-primary-coral text-white rounded-full font-semibold active:opacity-80 transition-opacity shadow-sm"
                >
                  확인
                </button>
              </div>
            ) : (
              <div className="space-y-3">
                <button
                  onClick={handleInstallApp}
                  disabled={installPending}
                  className="w-full px-6 py-3.5 bg-primary-coral text-white rounded-full font-semibold active:opacity-80 transition-opacity shadow-sm disabled:opacity-50"
                >
                  홈 화면에 추가
                </button>
                <button
                  onClick={handleSkipInstall}
                  className="w-full px-6 py-3.5 bg-white border border-neutral-200 rounded-full font-medium text-neutral-700 active:bg-neutral-50 transition-colors shadow-sm"
                >
                  나중에
                </button>
              </div>
            )}
          </div>
        )}

        {step === "done" && (
          <div className="space-y-6">
            <div className="text-center">
              <div className="w-24 h-24 mx-auto mb-4 rounded-full bg-primary-green/10 flex items-center justify-center">
                <CheckCircle size={48} className="text-primary-green" strokeWidth={2} />
              </div>
              <h2 className="text-3xl font-bold mb-2 text-neutral-900">모든 준비가 완료되었습니다!</h2>
              <p className="text-neutral-500">이제 대화를 시작해보세요</p>
            </div>

            <button
              onClick={handleFinish}
              className="w-full px-6 py-3.5 bg-primary-coral text-white rounded-full font-semibold active:opacity-80 transition-opacity shadow-sm"
            >
              시작하기
            </button>
          </div>
        )}
      </div>
    </div>
  );
}
