import type {
  User,
  Conversation,
  ConversationSummary,
  Message,
  AppState,
  Profile,
  ApiResponse,
  SendMessageResult,
  MessagesResponse,
  PushSubscription,
} from "@/types";

import { queueForSync } from "@/lib/offlineOutbox";

const API_URL = process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:3001";
const DEFAULT_TIMEOUT_MS = 30000;
// Direct-upload storage PUT floor — scaled up with file size at the call
// site so a large image on a slow-but-alive uplink isn't retry-proof, while
// small files keep fast stall detection
const UPLOAD_TIMEOUT_MS = 120000;
// Slowest sustained uplink the scaled bound waits for
const UPLOAD_MIN_BYTES_PER_SECOND = 16_384;

function isAbortError(e: unknown): e is Error {
  return e instanceof Error && e.name === "AbortError";
}

export class ApiError extends Error {
  constructor(
    message: string,
    public status?: number,
    public originalError?: unknown
  ) {
    super(message);
    this.name = "ApiError";
  }

  getUserMessage(): string {
    if (!this.status) {
      return "네트워크 연결을 확인해주세요";
    }

    switch (this.status) {
      case 400:
        return "잘못된 요청입니다";
      case 401:
        return "인증이 필요합니다";
      case 403:
        return "접근 권한이 없습니다";
      case 404:
        return "요청한 정보를 찾을 수 없습니다";
      case 408:
        return "요청 시간이 초과되었습니다. 네트워크 연결을 확인해주세요";
      case 422:
        return this.message || "입력 정보를 확인해주세요";
      case 429:
        return "너무 많은 요청이 발생했습니다. 잠시 후 다시 시도해주세요";
      case 500:
      case 502:
      case 503:
      case 504:
        return "서버 오류가 발생했습니다. 잠시 후 다시 시도해주세요";
      default:
        if (this.status >= 400 && this.status < 500) {
          return "요청 처리에 실패했습니다";
        }
        if (this.status >= 500) {
          return "서버 오류가 발생했습니다";
        }
        return this.message || "알 수 없는 오류가 발생했습니다";
    }
  }
}

// Internal type for ActiveStorage direct upload response
interface DirectUploadResponse {
  direct_upload: {
    url: string;
    headers: Record<string, string>;
  };
  signed_id: string;
}

class ApiClient {
  private baseUrl: string;
  private deviceId: string | null = null;

  constructor(baseUrl: string) {
    this.baseUrl = baseUrl;
  }

  setDeviceId(deviceId: string) {
    this.deviceId = deviceId;
    if (typeof window !== "undefined") {
      localStorage.setItem("device_id", deviceId);
    }
  }

  getDeviceId(): string | null {
    if (!this.deviceId && typeof window !== "undefined") {
      this.deviceId = localStorage.getItem("device_id");
    }
    return this.deviceId;
  }

  private buildHeaders(options: RequestInit = {}): Record<string, string> {
    const headers: Record<string, string> = {
      "Content-Type": "application/json",
    };

    if (options.headers) {
      const existingHeaders = new Headers(options.headers);
      existingHeaders.forEach((value, key) => {
        headers[key] = value;
      });
    }

    const deviceId = this.getDeviceId();
    if (deviceId) {
      headers["X-Device-ID"] = deviceId;
    }

    return headers;
  }

  // The timer stays armed until `consume` finishes reading the body — a
  // server that returns headers then stalls the stream must still hit the
  // bound, or UI gated on the promise (saving, sending) wedges with no
  // recovery path
  private async fetchWithTimeout<T>(
    url: string,
    init: RequestInit,
    timeoutMs: number,
    consume: (response: Response) => Promise<T>
  ): Promise<T> {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), timeoutMs);
    try {
      const response = await fetch(url, { ...init, signal: controller.signal });
      return await consume(response);
    } finally {
      clearTimeout(timeoutId);
    }
  }

  private async request<T>(
    endpoint: string,
    options: RequestInit = {},
    timeoutMs: number = DEFAULT_TIMEOUT_MS
  ): Promise<T> {
    const headers = this.buildHeaders(options);

    try {
      return await this.fetchWithTimeout(
        `${this.baseUrl}${endpoint}`,
        { ...options, headers },
        timeoutMs,
        async (response) => {
          if (!response.ok) {
            let errorMessage = `HTTP ${response.status}`;

            try {
              const errorData: { error?: string; errors?: string[] } | null =
                await response.json();
              if (errorData?.error) {
                errorMessage = errorData.error;
              } else if (errorData?.errors && Array.isArray(errorData.errors)) {
                errorMessage = errorData.errors.join(", ");
              }
            } catch (e) {
              // A timeout abort must keep its identity (mapped to 408 in the
              // outer catch); everything else here is a non-JSON/empty body
              if (isAbortError(e)) throw e;
              errorMessage = response.statusText || errorMessage;
            }

            throw new ApiError(errorMessage, response.status);
          }

          try {
            return (await response.json()) as T;
          } catch (e) {
            if (isAbortError(e)) throw e;
            // The server responded (2xx) — a status-bearing error keeps this
            // out of the offline replay queue, which must never re-send a
            // request the server may have committed
            throw new ApiError("서버 응답을 읽지 못했습니다", response.status, e);
          }
        }
      );
    } catch (error) {
      if (error instanceof ApiError) {
        throw error;
      }

      if (isAbortError(error)) {
        throw new ApiError(
          "요청 시간이 초과되었습니다",
          408,
          error
        );
      }

      throw new ApiError(
        "네트워크 오류가 발생했습니다",
        undefined,
        error
      );
    }
  }

  async authenticate(): Promise<ApiResponse<{ user: User; authenticated: boolean }>> {
    const response = await this.request<{ user: User; authenticated: boolean }>(
      "/api/v1/auth/authenticate",
      {
        method: "POST",
      }
    );

    if (response.user?.device_id) {
      this.setDeviceId(response.user.device_id);
    }

    return { data: response };
  }

  async verifyAuth(): Promise<ApiResponse<{ user: User; authenticated: boolean }>> {
    const response = await this.request<{ user: User; authenticated: boolean }>("/api/v1/auth/verify");
    return { data: response };
  }

  async createDeviceLink(): Promise<ApiResponse<{ code: string; expires_in: number }>> {
    const response = await this.request<{ code: string; expires_in: number }>(
      "/api/v1/device_links",
      { method: "POST" }
    );
    return { data: response };
  }

  // Callable without an established identity: the claiming install's code
  // IS its credential
  async claimDeviceLink(code: string): Promise<ApiResponse<{ device_id: string }>> {
    const response = await this.request<{ device_id: string }>(
      "/api/v1/device_links/claim",
      { method: "POST", body: JSON.stringify({ code }) }
    );
    return { data: response };
  }

  async getAppState(): Promise<ApiResponse<AppState>> {
    const response = await this.request<{ app_state: AppState }>("/api/v1/app_state");
    return { data: response.app_state };
  }

  async getConversations(): Promise<ApiResponse<{ conversations: ConversationSummary[] }>> {
    const response = await this.request<{ conversations: ConversationSummary[] }>("/api/v1/conversations");
    return { data: response };
  }

  async getCurrentConversation(): Promise<ApiResponse<{ conversation: Conversation }>> {
    const response = await this.request<{ conversation: Conversation }>("/api/v1/conversations/current");
    return { data: response };
  }

  async getConversation(conversationId: number): Promise<ApiResponse<{ conversation: Conversation }>> {
    const response = await this.request<{ conversation: Conversation }>(`/api/v1/conversations/${conversationId}`);
    return { data: response };
  }

  async getMessages(
    conversationId: number,
    limit: number = 100,
    beforeId?: number
  ): Promise<MessagesResponse> {
    let url = `/api/v1/conversations/${conversationId}/messages?limit=${limit}`;
    if (beforeId) {
      url += `&before_id=${beforeId}`;
    }
    return this.request<MessagesResponse>(url);
  }

  async sendMessage(
    conversationId: number,
    content: string
  ): Promise<SendMessageResult> {
    const endpoint = `/api/v1/conversations/${conversationId}/messages`;
    const body = JSON.stringify({ content });

    try {
      const response = await this.request<{ message: Message }>(endpoint, {
        method: "POST",
        body,
      });
      return { data: response };
    } catch (error) {
      // Timeouts (408) and 2xx body-read failures are deliberately NOT
      // queued: in both cases the POST may already have committed
      // server-side, and messages carry no dedup key, so a replay would
      // duplicate the message and trigger a second AI cycle. Only failures
      // that provably never completed a round-trip are replayable.
      const isNetworkError =
        error instanceof ApiError && error.status === undefined;

      if (isNetworkError) {
        const queued = await queueForSync({
          url: `${this.baseUrl}${endpoint}`,
          method: "POST",
          headers: this.buildHeaders(),
          body,
        });
        if (queued) {
          return { queued: true };
        }
      }

      throw error;
    }
  }

  async markMessagesAsRead(
    conversationId: number,
    messageIds: number[]
  ): Promise<ApiResponse<void>> {
    await this.request<void>(
      `/api/v1/conversations/${conversationId}/messages/mark_as_read`,
      {
        method: "POST",
        body: JSON.stringify({ message_ids: messageIds }),
      }
    );
    return {};
  }

  async updateUserState(
    conversationId: number,
    state: { typing?: boolean; focused?: boolean; scroll_position?: number }
  ): Promise<ApiResponse<void>> {
    await this.request<void>(
      `/api/v1/conversations/${conversationId}/user_state`,
      {
        method: "PUT",
        body: JSON.stringify(state),
      }
    );
    return {};
  }

  async getUser(): Promise<ApiResponse<{ user: User }>> {
    const response = await this.request<{ user: User }>("/api/v1/user");
    return { data: response };
  }

  async updateUser(data: Partial<User>): Promise<ApiResponse<{ user: User }>> {
    const response = await this.request<{ user: User }>("/api/v1/user", {
      method: "PUT",
      body: JSON.stringify({ user: data }),
    });
    return { data: response };
  }

  async getAiProfile(): Promise<ApiResponse<{ profile: Profile }>> {
    const response = await this.request<{ profile: Profile }>("/api/v1/profiles/ai");
    return { data: response };
  }

  async getMyProfile(): Promise<ApiResponse<{ profile: Profile }>> {
    const response = await this.request<{ profile: Profile }>("/api/v1/profiles/me");
    return { data: response };
  }

  async updateMyProfile(
    profile: Partial<Profile>,
    profilePictureSignedId?: string
  ): Promise<ApiResponse<{ profile: Profile }>> {
    const body: {
      profile: Partial<Profile> & { profile_picture_signed_id?: string };
    } = { profile: { ...profile } };
    if (profilePictureSignedId) {
      body.profile.profile_picture_signed_id = profilePictureSignedId;
    }

    const response = await this.request<{ profile: Profile }>("/api/v1/profiles/me", {
      method: "PUT",
      body: JSON.stringify(body),
    });
    return { data: response };
  }

  async uploadFile(file: File): Promise<string> {
    try {
      if (!file || file.size === 0) {
        throw new ApiError("파일이 비어있습니다", 400);
      }

      const blobData = {
        blob: {
          filename: file.name,
          byte_size: file.size,
          checksum: await this.calculateChecksum(file),
          content_type: file.type,
          metadata: {}
        }
      };

      const response = await this.request<DirectUploadResponse>("/api/v1/direct_uploads", {
        method: "POST",
        body: JSON.stringify(blobData),
      });

      if (!response.direct_upload?.url || !response.signed_id) {
        throw new ApiError("파일 업로드 준비에 실패했습니다", 500);
      }

      // Bounded like every other request — consumers gate UI on the save
      // being in flight, so an unbounded stalled PUT would trap them
      const uploadTimeoutMs = Math.max(
        UPLOAD_TIMEOUT_MS,
        60_000 + Math.ceil(file.size / UPLOAD_MIN_BYTES_PER_SECOND) * 1000
      );
      await this.fetchWithTimeout(
        response.direct_upload.url,
        {
          method: "PUT",
          headers: response.direct_upload.headers,
          body: file,
        },
        uploadTimeoutMs,
        async (uploadResponse) => {
          if (!uploadResponse.ok) {
            const errorText = await uploadResponse.text().catch((e) => {
              if (isAbortError(e)) throw e;
              return "";
            });
            throw new ApiError(
              `파일 업로드 실패: ${errorText || uploadResponse.statusText}`,
              uploadResponse.status
            );
          }
        }
      );

      return response.signed_id;
    } catch (error) {
      if (error instanceof ApiError) {
        throw error;
      }
      if (isAbortError(error)) {
        throw new ApiError("파일 업로드 시간이 초과되었습니다", 408, error);
      }
      throw new ApiError(
        "파일 업로드 중 오류가 발생했습니다",
        undefined,
        error
      );
    }
  }

  private async calculateChecksum(file: File): Promise<string> {
    const buffer = await file.arrayBuffer();
    const hashBuffer = await crypto.subtle.digest("SHA-256", buffer);
    const hashArray = Array.from(new Uint8Array(hashBuffer));
    const hashBase64 = btoa(String.fromCharCode(...hashArray));
    return hashBase64;
  }

  async createSubscription(
    subscription: PushSubscription
  ): Promise<ApiResponse<void>> {
    await this.request<void>("/api/v1/subscriptions", {
      method: "POST",
      body: JSON.stringify({ subscription }),
    });
    return {};
  }

  async deleteSubscription(endpoint: string): Promise<ApiResponse<void>> {
    await this.request<void>(
      `/api/v1/subscriptions?endpoint=${encodeURIComponent(endpoint)}`,
      {
        method: "DELETE",
      }
    );
    return {};
  }
}

export const apiClient = new ApiClient(API_URL);
