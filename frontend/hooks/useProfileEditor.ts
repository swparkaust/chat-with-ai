import { useLayoutEffect, useState } from "react";
import { apiClient } from "@/lib/api";
import type { Profile } from "@/types";

const VALID_IMAGE_TYPES = ["image/jpeg", "image/jpg", "image/png", "image/gif", "image/webp"];
const MAX_IMAGE_SIZE = 5 * 1024 * 1024;

function validateImageFile(file: File): string | null {
  if (!VALID_IMAGE_TYPES.includes(file.type)) {
    return "이미지 파일만 업로드할 수 있습니다 (JPEG, PNG, GIF, WebP)";
  }

  if (file.size > MAX_IMAGE_SIZE) {
    return "파일 크기는 5MB 이하여야 합니다";
  }

  return null;
}

export function useProfileEditor() {
  const [profilePicture, setProfilePicture] = useState<File | null>(null);
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);
  const [uploadError, setUploadError] = useState<string | null>(null);
  const [saveError, setSaveError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  // previewUrl is derived from the picked file; this effect is the sole
  // owner of object-URL creation and revocation (outgoing URL on every
  // replacement, the last one on unmount). Layout effect so the new preview
  // commits before paint instead of one frame after.
  useLayoutEffect(() => {
    if (!profilePicture) {
      setPreviewUrl(null);
      return;
    }

    const url = URL.createObjectURL(profilePicture);
    setPreviewUrl(url);
    return () => {
      URL.revokeObjectURL(url);
    };
  }, [profilePicture]);

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
  };

  const clearPicture = () => {
    setProfilePicture(null);
    setUploadError(null);
    setSaveError(null);
  };

  const saveProfile = async (profile: Partial<Profile>) => {
    setSaving(true);
    setSaveError(null);
    try {
      let profilePictureSignedId: string | undefined;
      if (profilePicture) {
        // Fresh upload per attempt — a signed id cached across retries can
        // outlive the backend's unattached-blob retention and poison every
        // retry; orphans from failed attempts are swept by PeriodicTasksJob
        profilePictureSignedId = await apiClient.uploadFile(profilePicture);
      }

      await apiClient.updateMyProfile(profile, profilePictureSignedId);
      // Deliberately no clearPicture() here: the preview must outlive the
      // save so the consumer can keep showing it until its own refetch
      // lands (clearing first flashes the stale server picture)
    } catch (err) {
      setSaveError("프로필 저장에 실패했습니다. 다시 시도해주세요");
      throw err;
    } finally {
      setSaving(false);
    }
  };

  return {
    previewUrl,
    uploadError,
    saveError,
    saving,
    handleFileChange,
    clearPicture,
    saveProfile,
  };
}
