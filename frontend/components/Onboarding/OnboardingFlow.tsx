"use client";

import { useState, useEffect } from "react";
import { Bell, Smartphone, CheckCircle } from "lucide-react";
import { apiClient } from "@/lib/api";
import { logger } from "@/lib/logger";
import { usePushNotifications } from "@/hooks/usePushNotifications";
import { usePWAInstall } from "@/hooks/usePWAInstall";
import { useAppName } from "@/hooks/useAppName";
import { useDocumentTitle } from "@/hooks/useDocumentTitle";
import ProfilePicture from "@/components/Common/ProfilePicture";
import type { User } from "@/types";

interface OnboardingFlowProps {
  user: User;
  onComplete: () => void;
}

type Step = "profile" | "notifications" | "install" | "done";

export default function OnboardingFlow({ user, onComplete }: OnboardingFlowProps) {
  const [step, setStep] = useState<Step>("profile");
  const [name, setName] = useState("");
  const [statusMessage, setStatusMessage] = useState("");
  const [profilePicture, setProfilePicture] = useState<File | null>(null);
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [isClosing, setIsClosing] = useState(false);
  const { subscribe, permission, isSupported: notificationsSupported } = usePushNotifications();
  const { promptInstall, isInstallable } = usePWAInstall();
  const { appName } = useAppName();
  useDocumentTitle();

  useEffect(() => {
    return () => {
      if (previewUrl) {
        URL.revokeObjectURL(previewUrl);
      }
    };
  }, [previewUrl]);

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      setProfilePicture(file);
      const url = URL.createObjectURL(file);
      setPreviewUrl(url);
    }
  };

  const handleProfileSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    if (!name.trim()) return;

    try {
      setSaving(true);

      let profilePictureSignedId: string | undefined;
      if (profilePicture) {
        profilePictureSignedId = await apiClient.uploadFile(profilePicture);
      }

      await apiClient.updateMyProfile(
        { name, status_message: statusMessage },
        profilePictureSignedId
      );

      if (previewUrl) {
        URL.revokeObjectURL(previewUrl);
      }

      setStep("notifications");
    } catch (err) {
      logger.error("Failed to save profile:", err);
    } finally {
      setSaving(false);
    }
  };

  const handleEnableNotifications = async () => {
    const success = await subscribe();
    if (success || permission === "granted") {
      setStep(isInstallable ? "install" : "done");
    } else {
      // Still move forward even if user declined
      setStep(isInstallable ? "install" : "done");
    }
  };

  const handleSkipNotifications = () => {
    setStep(isInstallable ? "install" : "done");
  };

  const handleInstallApp = async () => {
    await promptInstall();
    setStep("done");
  };

  const handleSkipInstall = () => {
    setStep("done");
  };

  const handleFinish = () => {
    setIsClosing(true);
    setTimeout(() => {
      onComplete();
    }, 250);
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
                    className="hidden"
                  />
                </label>
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
                    className="w-full text-base text-neutral-900 font-medium bg-transparent outline-none placeholder:text-neutral-400"
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
                    className="w-full text-base text-neutral-800 bg-transparent outline-none placeholder:text-neutral-400"
                    placeholder="상태 메시지를 입력하세요 (선택)"
                  />
                </div>
              </div>

              <button
                type="submit"
                disabled={!name.trim() || saving}
                className="w-full mt-2 px-6 py-3.5 bg-primary-coral text-white rounded-full font-semibold active:opacity-80 transition-opacity shadow-sm disabled:opacity-40"
              >
                {saving ? "저장 중..." : "다음"}
              </button>
            </form>
          </div>
        )}

        {step === "notifications" && notificationsSupported && (
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
                className="w-full px-6 py-3.5 bg-primary-coral text-white rounded-full font-semibold active:opacity-80 transition-opacity shadow-sm"
              >
                알림 켜기
              </button>
              <button
                onClick={handleSkipNotifications}
                className="w-full px-6 py-3.5 bg-white border border-neutral-200 rounded-full font-medium text-neutral-700 active:bg-neutral-50 transition-colors shadow-sm"
              >
                나중에
              </button>
            </div>
          </div>
        )}

        {step === "install" && isInstallable && (
          <div className="space-y-6">
            <div className="text-center">
              <div className="w-24 h-24 mx-auto mb-4 rounded-full bg-primary-coral/10 flex items-center justify-center">
                <Smartphone size={48} className="text-primary-coral" strokeWidth={2} />
              </div>
              <h2 className="text-3xl font-bold mb-2 text-neutral-900">홈 화면에 추가</h2>
              <p className="text-neutral-500">앱처럼 빠르게 실행할 수 있어요</p>
            </div>

            <div className="space-y-3">
              <button
                onClick={handleInstallApp}
                className="w-full px-6 py-3.5 bg-primary-coral text-white rounded-full font-semibold active:opacity-80 transition-opacity shadow-sm"
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
