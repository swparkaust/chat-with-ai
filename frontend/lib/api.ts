import type {
  User,
  Season,
  Conversation,
  ConversationSummary,
  Message,
  AppState,
  Profile,
  ApiResponse,
  PaginatedResponse,
  MessagesResponse,
  PushSubscription,
} from "@/types";

const API_URL = process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:3001";
const DEFAULT_TIMEOUT_MS = 30000;

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

  private async request<T>(
    endpoint: string,
    options: RequestInit = {},
    timeoutMs: number = DEFAULT_TIMEOUT_MS
  ): Promise<T> {
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

    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), timeoutMs);

    try {
      const response = await fetch(`${this.baseUrl}${endpoint}`, {
        ...options,
        headers,
        signal: controller.signal,
      });

      clearTimeout(timeoutId);

      if (!response.ok) {
        let errorMessage = `HTTP ${response.status}`;
        let errorData: { error?: string; errors?: string[] } | null = null;

        try {
          errorData = await response.json();
          if (errorData?.error) {
            errorMessage = errorData.error;
          } else if (errorData?.errors && Array.isArray(errorData.errors)) {
            errorMessage = errorData.errors.join(", ");
          }
        } catch {
          // Response body is not JSON or is empty
          errorMessage = response.statusText || errorMessage;
        }

        throw new ApiError(errorMessage, response.status);
      }

      return response.json();
    } catch (error) {
      clearTimeout(timeoutId);

      if (error instanceof ApiError) {
        throw error;
      }

      if (error instanceof Error && error.name === 'AbortError') {
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

  async getAppState(): Promise<ApiResponse<AppState>> {
    const response = await this.request<{ app_state: AppState }>("/api/v1/app_state");
    return { data: response.app_state };
  }

  async getSeasons(): Promise<ApiResponse<{ seasons: Season[] }>> {
    const response = await this.request<{ seasons: Season[] }>("/api/v1/seasons");
    return { data: response };
  }

  async getCurrentSeason(): Promise<ApiResponse<{ season: Season }>> {
    const response = await this.request<{ season: Season }>("/api/v1/seasons/current");
    return { data: response };
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
    page?: number,
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
  ): Promise<ApiResponse<{ message: Message }>> {
    const response = await this.request<{ message: Message }>(
      `/api/v1/conversations/${conversationId}/messages`,
      {
        method: "POST",
        body: JSON.stringify({ content }),
      }
    );
    return { data: response };
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
    typing: boolean
  ): Promise<ApiResponse<void>> {
    await this.request<void>(
      `/api/v1/conversations/${conversationId}/user_state`,
      {
        method: "PUT",
        body: JSON.stringify({ typing }),
      }
    );
    return {};
  }

  async updateUserFocus(
    conversationId: number,
    focused: boolean
  ): Promise<ApiResponse<void>> {
    await this.request<void>(
      `/api/v1/conversations/${conversationId}/user_state`,
      {
        method: "PUT",
        body: JSON.stringify({ focused }),
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

      const uploadResponse = await fetch(response.direct_upload.url, {
        method: "PUT",
        headers: response.direct_upload.headers,
        body: file,
      });

      if (!uploadResponse.ok) {
        const errorText = await uploadResponse.text().catch(() => "");
        throw new ApiError(
          `파일 업로드 실패: ${errorText || uploadResponse.statusText}`,
          uploadResponse.status
        );
      }

      return response.signed_id;
    } catch (error) {
      if (error instanceof ApiError) {
        throw error;
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
      `/api/v1/subscriptions/${encodeURIComponent(endpoint)}`,
      {
        method: "DELETE",
      }
    );
    return {};
  }
}

export const apiClient = new ApiClient(API_URL);
