export const SCROLL_DEBOUNCE_MS = 100;       // Debounce for scroll event handlers
export const READ_RECEIPT_DEBOUNCE_MS = 500; // Debounce before marking messages as read
export const TYPING_TIMEOUT_MS = 1000;       // Timeout to clear typing indicator

export const SCROLL_THRESHOLD_PX = 50;

export const MESSAGE_PAGE_SIZE = 50;

// Shared by InstallPrompt (reads it to suppress the ambient banner) and
// OnboardingFlow (writes it after the iOS share-sheet walkthrough)
export const INSTALL_PROMPT_DISMISSED_KEY = "install_prompt_dismissed";
export const NOTIFICATION_PROMPT_DISMISSED_KEY = "notification_prompt_dismissed";
export const ONBOARDING_COMPLETED_KEY = "onboarding_completed";
export const INSTALL_ASK_DEFERRED_SESSION_KEY = "install_ask_deferred";
