export interface User {
  id: number;
  device_id: string;
  name: string | null;
  status_message: string | null;
  profile_picture: string | null;
  created_at?: string; // Only returned in GET /api/v1/user
}

export interface Season {
  id: number;
  season_number: number;
  first_name: string;
  last_name: string;
  full_name: string;
  profile_picture: string | null;
  status_message: string | null;
  active: boolean;
  start_date: string;
  end_date?: string | null;
}

export interface Conversation {
  id: number;
  user_id: number;
  season_id: number;
  season?: Season;
  created_at: string;
  updated_at: string;
}

// ConversationSummary for index endpoint (extended format)
export interface ConversationSummary {
  id: number;
  season_id: number;
  season_number: number;
  first_name: string;
  full_name: string;
  profile_picture: string | null;
  active: boolean;
  last_message_at: string;
  unread_count: number;
  last_message_preview: string | null;
}

export interface Message {
  id: number;
  sender_type: "user" | "ai";
  content: string;
  read_at: string | null;
  created_at: string;
  is_fragment?: boolean;
  fragment_index?: number;
}

export interface AppState {
  version: string;
  season_number: number;
  active_users: number;
  total_users: number;
  has_active_season: boolean;
}

export interface Profile {
  name?: string; // For user profiles
  first_name?: string; // For AI profiles
  last_name?: string; // For AI profiles
  full_name?: string; // For AI profiles
  status_message: string | null;
  profile_picture: string | null;
  // AI-specific fields
  age?: number;
  occupation?: string;
  interests?: string[];
  personality_traits?: string[];
}

export interface ApiResponse<T> {
  data?: T;
  error?: string;
  message?: string;
}

export interface PaginatedResponse<T> {
  data: T[];
  pagination: {
    current_page: number;
    total_pages: number;
    total_count: number;
    per_page: number;
  };
}

export interface MessagesResponse {
  messages: Message[];
  has_more: boolean;
}

export interface WebSocketMessage {
  type: string;
  [key: string]: unknown;
}

export interface ConversationChannelMessage extends WebSocketMessage {
  type: "message" | "typing" | "read_receipt" | "notification_bell";
  message?: Message;
  is_typing?: boolean;
  sender_type?: "user" | "ai";
  message_id?: number;
  ring?: boolean; // For notification_bell
}

export interface AppStateChannelMessage extends WebSocketMessage {
  type: "initial_state" | "state_update" | "season_change" | "season_rotated" | "active_users_update";
  season_number?: number;
  active_users?: number;
  count?: number; // For active_users_update
  version?: string;
  new_season?: Season;
}

export interface PushSubscription {
  endpoint: string;
  p256dh_key: string;
  auth_key: string;
}

export interface ProfileFormData {
  name: string;
  status_message: string;
}
