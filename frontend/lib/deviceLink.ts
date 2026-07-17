import { apiClient, ApiError } from "./api";
import { ONBOARDING_COMPLETED_KEY } from "./constants";

// Mirrors the backend's exact-length contract (6 chars after stripping
// separators/noise) so incomplete or over-long input stays unsubmittable
export function isCompleteLinkCode(code: string): boolean {
  return code.replace(/[^A-Z2-9]/g, "").length === 6;
}

// Claim the code and adopt its identity. Persist the device_id FIRST — a
// failure after that degrades to re-running onboarding as the adopted user.
// Ends in a reload so every hook re-initializes under the new identity;
// callers must not reset their loading state on success.
export async function adoptDeviceIdentity(code: string): Promise<void> {
  const response = await apiClient.claimDeviceLink(code);
  if (!response.data?.device_id) {
    throw new Error("empty claim response");
  }
  apiClient.setDeviceId(response.data.device_id);
  localStorage.setItem(ONBOARDING_COMPLETED_KEY, "true");
  window.location.reload();
}

export function claimErrorMessage(err: unknown): string {
  // The backend's 404 covers wrong AND expired AND already-used codes —
  // GETDEL burns a code even when its success response is lost in transit
  if (err instanceof ApiError) {
    return err.status === 404
      ? "코드가 올바르지 않거나, 만료되었거나, 이미 사용되었어요"
      : err.getUserMessage();
  }
  return "코드를 확인하지 못했어요";
}
