"use client";

import { useState, useEffect, useRef } from "react";
import { ChevronLeft } from "lucide-react";
import { apiClient } from "@/lib/api";
import { logger } from "@/lib/logger";
import ProfilePicture from "@/components/Common/ProfilePicture";
import type { Profile } from "@/types";

interface ProfileSheetProps {
  type: "user" | "ai";
  onClose: () => void;
}

export default function ProfileSheet({ type, onClose }: ProfileSheetProps) {
  const [profile, setProfile] = useState<Profile | null>(null);
  const [loading, setLoading] = useState(true);
  const [editing, setEditing] = useState(false);
  const [formData, setFormData] = useState({
    name: "",
    status_message: "",
  });
  const [profilePicture, setProfilePicture] = useState<File | null>(null);
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [uploadError, setUploadError] = useState<string | null>(null);
  const [isClosing, setIsClosing] = useState(false);
  const mountedRef = useRef(true);

  const isUserProfile = type === "user";

  useEffect(() => {
    loadProfile();
    return () => {
      mountedRef.current = false;
      if (previewUrl) {
        URL.revokeObjectURL(previewUrl);
      }
    };
  }, []);

  const loadProfile = async () => {
    try {
      setLoading(true);
      const response = isUserProfile
        ? await apiClient.getMyProfile()
        : await apiClient.getAiProfile();

      if (response.data) {
        setProfile(response.data.profile);
        if (isUserProfile && mountedRef.current) {
          setFormData({
            name: response.data.profile.name ?? "",
            status_message: response.data.profile.status_message ?? "",
          });
        }
      }
    } catch (err) {
      logger.error("Failed to load profile:", err);
    } finally {
      setLoading(false);
    }
  };

  const validateImageFile = (file: File): string | null => {
    const validTypes = ["image/jpeg", "image/jpg", "image/png", "image/gif", "image/webp"];
    if (!validTypes.includes(file.type)) {
      return "이미지 파일만 업로드할 수 있습니다 (JPEG, PNG, GIF, WebP)";
    }

    const maxSize = 5 * 1024 * 1024;
    if (file.size > maxSize) {
      return "파일 크기는 5MB 이하여야 합니다";
    }

    return null;
  };

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    setUploadError(null);

    if (!file) return;

    const error = validateImageFile(file);
    if (error) {
      setUploadError(error);
      e.target.value = "";
      return;
    }

    setProfilePicture(file);
    const url = URL.createObjectURL(file);
    setPreviewUrl(url);
  };

  const handleSave = async () => {
    try {
      setSaving(true);

      let profilePictureSignedId: string | undefined;
      if (profilePicture) {
        profilePictureSignedId = await apiClient.uploadFile(profilePicture);
      }

      await apiClient.updateMyProfile(formData, profilePictureSignedId);

      if (previewUrl) {
        URL.revokeObjectURL(previewUrl);
        setPreviewUrl(null);
      }
      setProfilePicture(null);

      await loadProfile();

      setEditing(false);
    } catch (err) {
      logger.error("Failed to update profile:", err);
    } finally {
      setSaving(false);
    }
  };

  const handleClose = () => {
    setIsClosing(true);
    setTimeout(() => {
      onClose();
    }, 250);
  };

  const handleCancel = () => {
    setFormData({
      name: profile?.name ?? "",
      status_message: profile?.status_message ?? "",
    });

    if (previewUrl) {
      URL.revokeObjectURL(previewUrl);
      setPreviewUrl(null);
    }
    setProfilePicture(null);
    setUploadError(null);
    setEditing(false);
  };

  const displayName = isUserProfile
    ? (profile?.name ?? "이름 없음")
    : (profile?.full_name ?? "");

  return (
    <div
      className={`fixed inset-0 z-50 bg-white ${isClosing ? 'animate-modal-exit' : 'animate-modal-enter'}`}
      onClick={(e) => e.stopPropagation()}
    >
      <div className="h-full flex flex-col">
        <div className="sticky top-0 z-10 bg-white/80 backdrop-blur-xl border-b border-neutral-200/60">
          <div className="px-4 h-14 flex items-center justify-between">
            <button
              onClick={handleClose}
              className="flex items-center gap-2 text-primary-coral font-medium active:opacity-60 transition-opacity"
            >
              <ChevronLeft size={24} strokeWidth={2.5} />
              <span>뒤로</span>
            </button>
            {isUserProfile && (
              editing ? (
                <button
                  onClick={handleSave}
                  disabled={saving || !formData.name.trim()}
                  className="text-primary-coral font-semibold disabled:opacity-40 active:opacity-60 transition-opacity"
                >
                  {saving ? "저장 중..." : "완료"}
                </button>
              ) : (
                <button
                  onClick={() => setEditing(true)}
                  className="text-primary-coral font-semibold active:opacity-60 transition-opacity"
                >
                  편집
                </button>
              )
            )}
          </div>
        </div>

        {loading ? (
          <div className="flex-1 flex items-center justify-center">
            <div className="flex flex-col items-center gap-4">
              <div className="w-12 h-12 rounded-full border-4 border-primary-coral border-t-transparent animate-spin" />
              <p className="text-sm text-neutral-500">불러오는 중...</p>
            </div>
          </div>
        ) : profile ? (
          <div className="flex-1 overflow-y-auto bg-gradient-to-b from-white to-neutral-50">
            <div className="flex flex-col items-center pt-8 pb-6 px-4">
              <div className="relative mb-4">
                <ProfilePicture
                  imageUrl={previewUrl ?? profile.profile_picture}
                  size="xl"
                  alt={displayName}
                  className="shadow-elevated-lg"
                />
              </div>

              {isUserProfile && editing && (
                <label className="mb-2 px-5 py-2.5 bg-white border border-neutral-200 rounded-full text-sm font-medium text-primary-coral cursor-pointer active:bg-neutral-50 transition-colors shadow-sm">
                  사진 변경
                  <input
                    type="file"
                    accept="image/*"
                    onChange={handleFileChange}
                    className="hidden"
                  />
                </label>
              )}

              {uploadError && (
                <p className="text-sm text-primary-red text-center px-4 mb-2">
                  {uploadError}
                </p>
              )}
            </div>

            <div className="px-4 pb-8">
              <div className="bg-white rounded-2xl shadow-sm overflow-hidden mb-6">
                <div className="px-4 py-3.5 border-b border-neutral-100">
                  <label className="text-xs font-medium text-neutral-500 uppercase tracking-wide">
                    이름
                  </label>
                </div>
                <div className="px-4 py-3.5">
                  {isUserProfile && editing ? (
                    <input
                      type="text"
                      value={formData.name}
                      onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                      className="w-full text-base text-neutral-900 font-medium bg-transparent outline-none placeholder:text-neutral-400"
                      placeholder="이름을 입력하세요"
                    />
                  ) : (
                    <p className="text-base text-neutral-900 font-medium">
                      {displayName}
                    </p>
                  )}
                </div>
              </div>

              <div className="bg-white rounded-2xl shadow-sm overflow-hidden">
                <div className="px-4 py-3.5 border-b border-neutral-100">
                  <label className="text-xs font-medium text-neutral-500 uppercase tracking-wide">
                    상태 메시지
                  </label>
                </div>
                <div className="px-4 py-3.5">
                  {isUserProfile && editing ? (
                    <input
                      type="text"
                      value={formData.status_message}
                      onChange={(e) => setFormData({ ...formData, status_message: e.target.value })}
                      className="w-full text-base text-neutral-800 bg-transparent outline-none placeholder:text-neutral-400"
                      placeholder="상태 메시지를 입력하세요"
                    />
                  ) : profile.status_message ? (
                    <p className="text-base text-neutral-800">{profile.status_message}</p>
                  ) : (
                    <p className="text-base text-neutral-400">상태 메시지 없음</p>
                  )}
                </div>
              </div>

              {isUserProfile && editing && (
                <button
                  onClick={handleCancel}
                  disabled={saving}
                  className="w-full mt-6 px-6 py-3.5 bg-white border border-neutral-200 rounded-full font-medium text-neutral-700 active:bg-neutral-50 transition-colors shadow-sm disabled:opacity-50"
                >
                  취소
                </button>
              )}
            </div>
          </div>
        ) : (
          <div className="flex-1 flex items-center justify-center px-4">
            <p className="text-neutral-500">프로필을 불러올 수 없습니다</p>
          </div>
        )}
      </div>
    </div>
  );
}
