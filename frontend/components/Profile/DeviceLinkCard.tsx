"use client";

import { useState, useEffect } from "react";
import { apiClient } from "@/lib/api";
import {
  adoptDeviceIdentity,
  claimErrorMessage,
  isCompleteLinkCode,
} from "@/lib/deviceLink";
import { MESSAGE_PAGE_SIZE } from "@/lib/constants";
import { logger } from "@/lib/logger";

// The "다른 기기에서 이어가기" card: mints single-use link codes for carrying
// this identity to a new install, and — for provably-throwaway identities
// only — offers claiming a code from another device.
export default function DeviceLinkCard() {
  const [deviceLinkCode, setDeviceLinkCode] = useState<string | null>(null);
  const [deviceLinkExpiresIn, setDeviceLinkExpiresIn] = useState<number | null>(null);
  const [deviceLinkError, setDeviceLinkError] = useState<string | null>(null);
  const [deviceLinkLoading, setDeviceLinkLoading] = useState(false);
  const [claimEligible, setClaimEligible] = useState(false);
  const [claimCode, setClaimCode] = useState("");
  const [claimError, setClaimError] = useState<string | null>(null);
  const [claimLoading, setClaimLoading] = useState(false);

  // The claim entry may only replace a THROWAWAY identity — offered solely
  // when this device's user has never sent a message (the mis-tapped-through-
  // onboarding population, for whom the claim step is otherwise gone forever)
  useEffect(() => {
    let cancelled = false;

    (async () => {
      try {
        const conv = (await apiClient.getCurrentConversation()).data?.conversation;
        if (!conv) {
          if (!cancelled) setClaimEligible(true);
          return;
        }
        const page = await apiClient.getMessages(conv.id, MESSAGE_PAGE_SIZE);
        const hasUserMessage =
          page.messages?.some((m) => m.sender_type === "user") ?? false;
        // A full first page is treated as real history without paging back
        if (!cancelled) {
          setClaimEligible(!hasUserMessage && !(page.has_more ?? false));
        }
      } catch {
        // Can't prove the identity is throwaway — keep the entry hidden
        if (!cancelled) setClaimEligible(false);
      }
    })();

    return () => {
      cancelled = true;
    };
  }, []);

  const handleClaim = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!window.confirm("현재 기기의 프로필을 기존 계정으로 교체합니다. 계속할까요?")) {
      return;
    }
    setClaimLoading(true);
    setClaimError(null);

    try {
      await adoptDeviceIdentity(claimCode);
      // No setClaimLoading(false): adoption ends in a reload
    } catch (err) {
      logger.error("Failed to claim device link:", err);
      setClaimError(claimErrorMessage(err));
      setClaimLoading(false);
    }
  };

  const handleCreateDeviceLink = async () => {
    setDeviceLinkLoading(true);
    setDeviceLinkError(null);

    try {
      const response = await apiClient.createDeviceLink();
      if (!response.data?.code) {
        throw new Error("empty device link response");
      }
      setDeviceLinkCode(response.data.code);
      setDeviceLinkExpiresIn(response.data.expires_in);
    } catch (err) {
      logger.error("Failed to create device link:", err);
      setDeviceLinkError("코드를 발급하지 못했어요. 다시 시도해주세요");
    } finally {
      setDeviceLinkLoading(false);
    }
  };

  return (
    <div className="bg-white rounded-2xl shadow-sm overflow-hidden">
      <div className="px-4 py-3.5 border-b border-neutral-100">
        <label className="text-xs font-medium text-neutral-500 uppercase tracking-wide">
          다른 기기에서 이어가기
        </label>
      </div>
      <div className="px-4 py-3.5">
        {deviceLinkCode ? (
          <div className="text-center space-y-2 py-1">
            <p className="text-3xl font-bold tracking-[0.2em] text-neutral-900">
              {deviceLinkCode.slice(0, 3)}-{deviceLinkCode.slice(3)}
            </p>
            <p className="text-sm text-neutral-500">
              {Math.round((deviceLinkExpiresIn ?? 600) / 60)}분 동안 1회 사용할
              수 있어요. 새 기기의 시작 화면에서 &lsquo;코드로
              이어가기&rsquo;에 입력하세요
            </p>
            <button
              onClick={handleCreateDeviceLink}
              disabled={deviceLinkLoading}
              className="text-sm font-medium text-primary-coral active:opacity-60 transition-opacity disabled:opacity-40"
            >
              {deviceLinkLoading ? "발급 중..." : "새 코드 발급"}
            </button>
            {deviceLinkError && (
              <p className="text-sm text-primary-red">{deviceLinkError}</p>
            )}
          </div>
        ) : (
          <div className="space-y-2">
            <button
              onClick={handleCreateDeviceLink}
              disabled={deviceLinkLoading}
              className="w-full px-5 py-2.5 bg-white border border-neutral-200 rounded-full text-sm font-medium text-primary-coral active:bg-neutral-50 transition-colors shadow-sm disabled:opacity-50"
            >
              {deviceLinkLoading ? "발급 중..." : "연결 코드 발급"}
            </button>
            <p className="text-xs text-neutral-400">
              홈 화면에 설치한 앱 등 새 기기에서 지금까지의 대화를 그대로 이어갈 수 있어요
            </p>
            {deviceLinkError && (
              <p className="text-sm text-primary-red">{deviceLinkError}</p>
            )}
          </div>
        )}

        {claimEligible && (
          <form
            onSubmit={handleClaim}
            className="mt-3 pt-3 border-t border-neutral-100 space-y-2"
          >
            <input
              type="text"
              value={claimCode}
              onChange={(e) => setClaimCode(e.target.value.toUpperCase())}
              disabled={claimLoading}
              autoCapitalize="characters"
              maxLength={7}
              className="w-full text-center text-lg tracking-[0.25em] font-semibold text-neutral-900 bg-neutral-50 rounded-xl px-3 py-2 outline-none placeholder:text-neutral-300 placeholder:tracking-normal disabled:opacity-50"
              placeholder="ABC-123"
            />
            <button
              type="submit"
              disabled={claimLoading || !isCompleteLinkCode(claimCode)}
              className="w-full px-5 py-2.5 bg-primary-coral text-white rounded-full text-sm font-medium active:opacity-80 transition-opacity shadow-sm disabled:opacity-40"
            >
              {claimLoading ? "확인 중..." : "코드로 이어가기"}
            </button>
            <p className="text-xs text-neutral-400">
              기존 기기에서 발급한 코드로 이 기기의 프로필을 교체해요
            </p>
            {claimError && <p className="text-sm text-primary-red">{claimError}</p>}
          </form>
        )}
      </div>
    </div>
  );
}
