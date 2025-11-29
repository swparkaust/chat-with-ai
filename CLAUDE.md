# ○○와 채팅하기 - Project Requirements

## Overview
Full-stack web application that creates realistic Korean messaging conversations with dynamically generated AI personas. Multi-user support with seasonal AI persona rotation.

## Technical Stack

### Backend
- **Framework**: Ruby on Rails 8.0.4 (API mode)
- **Database**: PostgreSQL with JSONB for flexible state storage
- **Real-time**: ActionCable (WebSocket) for live messaging
- **Background Jobs**: Sidekiq with Redis
- **AI API**: Google Gemini API (`gemini-2.5-flash` model)

### Frontend
- **Framework**: Next.js 15 with React 19
- **Language**: TypeScript
- **Styling**: Tailwind CSS (iOS-inspired design)
- **Real-time**: ActionCable client (`@rails/actioncable`)
- **PWA**: Service Worker with push notifications

### External Services
- **Weather**: wttr.in API
- **Search**: DuckDuckGo API
- **Web Fetch**: Custom service with Nokogiri parsing

## Core Features

### 1. AI Persona Generation
Generate AI persona via web interface or database seeding:

Generates comprehensive, multi-dimensional persona including:
- **Identity**: Name (Korean Hangul and Chinese Hanja), birthday (year/month/day with calculated age), sex, occupation, education, living situation, economic status, hometown
- **Personality**: Traits, communication style, values, speech patterns, humor style
- **Relationships**: Status, history, family structure, social circle, attachment style
- **Physical**: Appearance, fashion, health, energy level, sleep patterns, exercise habits
- **Interests**: Hobbies, music genres, reading habits, media consumption, skills
- **Psychology**: Emotional state, emotional triggers, insecurities, mental health, stress coping
- **Goals & Worries**: Short/long-term goals, current worries, regrets, bucket list
- **Habits & Preferences**: Daily routine, food preferences, substance use, tech savviness, spending habits
- **Memories**: Dynamic memory system with significance, emotional intensity, and decay
- **Context**: Current situation, life circumstances (continuously evolving)

### 2. Conversation Behavior

#### Korean Messaging Patterns
- **Aggressive message fragmentation** (breaking messages into many short fragments)
- **Internet slang** (Korean: ㅋㅋㅋ, ㄱㅅ, ㅇㅋ, etc.)
- **NO emojis** (Koreans prefer text-based expressions)
- **Spelling/grammatical errors** for authenticity
- **Never reveal AI nature**

#### Message Handling Logic
- **Bulk reading**: AI reads all unread user messages at once
- **No rereading**: Don't reread already-read messages
- **No self-response**: Don't respond to own messages
- **Context-aware**: Respond based on entire conversation thread
- **Dynamic reevaluation**: While sending message fragments, continuously check the latest thread and adjust remaining fragments or stop if needed
- **User interrupt**: User can send messages to cut off AI while typing/sending

#### AI-Driven Behavior
- **ALL business logic determined by AI** (timing, whether to respond, how to respond)
- **Can initiate conversations** at any time
- **Context-aware timing**: Check and reply timing based on persona's context and emotions
- **Optional responses**: AI can choose not to respond
- **읽씹 (Read without reply)**: AI can read messages but choose not to respond
  - Understands emotional difference between 읽씹 (read, ignored - more personal) and 안읽씹 (not read - less personal)
  - Reacts differently based on personality (anxious attachment = worried, secure = give space)
  - Can use 읽씹 strategically (upset, need space, passive-aggressive, busy)
- **Emotional authenticity**: Can express anger, argue, form relationships
- **Avoid being clingy** unless personality dictates otherwise

#### State Evolution
- Context, emotions, and memories continuously evolve in the background
- Changes should feel natural and human-like

### 3. Multi-User & Seasonal Features

#### Season System
- **Seasonal Rotation**: AI persona changes every 3 months
- **Season Numbering**: Starts at 1 and increments with each new persona generation
- **Deactivation Warning**:
  - ~2 weeks before rotation, notify all users
  - **CRITICAL**: Warning must use the same message send/receive flow as regular messages
  - Do NOT hardcode the message or create a specialized flow
  - AI generates natural farewell message without revealing AI nature
  - Gives users enough time to say goodbye
- **Multi-User Support**: Single AI persona shared across all users
- **Independent Conversations**: Each user has their own conversation thread
- **Independent AI Actions**: AI decides actions and sends messages independently per user, like humans do
- **Season Tracking**: Display current season number (starting at 1), active user count, app version without hardcoding values
- **Deactivated Season Access**:
  - Users can continue viewing conversations with deactivated AI personas
  - Chat input is disabled for deactivated seasons (view-only mode)
  - Backend prevents message sending to inactive conversations

#### Authentication
- **Device-Based**: Anonymous authentication using device IDs
- **No Signup Required**: Auto-authentication on first visit
- **Persistent Sessions**: Device ID stored in localStorage

### 4. UI/UX Requirements

#### Layout (iOS Messaging App Style)
- **iOS-inspired design** with Tailwind CSS custom theme
- Chat messages display in conversation format
- User messages aligned right (coral bubbles)
- AI messages aligned left (gray bubbles)
- Timestamps for messages (relative and absolute)
- **NO copyrighted trademarks in code or documentation**

#### Header
- Display: `{AI_FIRST_NAME}와 채팅하기`
- AI profile picture (or first initial)
- AI status message
- Season number, active users, app version

#### Input System
- Chat input **fixed to bottom** of viewport
- Auto-expanding textarea (max 120px)
- Users can send messages **at any time**
- Send on Enter (Shift+Enter for new line)
- Input always accessible
- Haptic feedback on send

#### Scrolling
- Allow scrolling to older messages (up)
- Allow scrolling to newer messages (down)
- **Auto-scroll** to newest message when new message arrives (if at bottom)
- **Scroll to bottom** button appears when user scrolls up
- **Infinite scroll** pagination for message history

#### Status Indicators
- **Read receipts**: Show "1" if message is unread by recipient
  - Messages marked as read **only when visible in viewport AND page is focused**
  - Uses IntersectionObserver API + Page Visibility API
  - User scrolling up to read history does not mark new messages as read
- **Typing indicator**: Show when AI is typing (animated dots)
- **Push notifications**: Browser notifications when page is not visible
  - Rings when page is not focused OR user is scrolled up
  - Does not ring when user is actively viewing conversation
  - Requires user permission (prompted after 3 seconds)

## Implementation Requirements

### Critical Rules
1. **NO placeholders** - All features must be fully implemented
2. **NO unnecessary documentation** - Only create essential docs
3. **Proper approach only** - Never take shortcuts or create simpler versions
4. **Never disable features** - Fix issues properly, don't remove functionality
5. **Clean up after fixes** - Remove all debugging logs and temporary files

### AI Integration
- Use Google Gemini API for:
  - Persona generation
  - Message generation
  - Timing decisions
  - Emotional state evolution
  - Context updates
  - Memory formation
  - Memory relevance scoring (semantic retrieval)
  - Tool usage decisions and execution

- Additional integrations:
  - Live weather data (wttr.in API) provided to AI for contextual awareness

#### Tool System
AI persona uses a plugin-based tool system for internal information management:

**Available Tools**:
- CalendarTool: Schedules, appointments, events
- ReminderTool: One-time and recurring reminders
- MemoTool: Quick notes with tags
- DiaryTool: Emotional logging and daily reflections
- TodoTool: Task management
- ContactsTool: Relationship and contact management
- WebSearchTool: Web search (DuckDuckGo)
- WebFetchTool: Web page content retrieval

**Tool Features**:
- Plugin architecture with BaseTool base class
- ToolManager coordinator for registration and execution
- AI-driven usage decisions (via Gemini API)
- Batch operations support
- Dynamic tool chaining (max 5 iterations, with previous results feedback)
- Time-based triggers (birthdays, reminders, events)
- Tool context included in AI system prompts

**Integration Points**: Tools checked at initial setup, periodic background checks, after AI responds, after AI initiates, and after read-only actions

### Language
- All conversations in **Korean**
- AI persona communicates naturally in Korean
- System prompts can be in English internally

## Architecture

### Database Schema

**Users Table**
- `device_id` (unique): Anonymous device identifier
- `name`, `status_message`: User profile
- `profile_picture` (ActiveStorage attachment): User profile picture
- `last_seen_at`: Activity tracking

**Seasons Table**
- `season_number`: Incremental season counter
- `start_date`, `active`: Season lifecycle
- `deactivation_warned_at`: Warning timestamp
- `profile_picture` (ActiveStorage attachment): AI persona profile picture

**ActiveStorage Tables**
- `active_storage_blobs`: File metadata
- `active_storage_attachments`: Polymorphic associations
- Direct upload pattern for client-side file uploads

**PersonaState Table** (per season)
- 90+ fields covering all persona dimensions
- JSONB fields for list data (traits, hobbies, etc.)
- Profile fields (name, status_message)
- Note: profile_picture is stored in Seasons table via ActiveStorage

**PersonaMemories Table**
- `content`: Memory text
- `significance`, `emotional_intensity`, `detail_level`: Memory metrics
- `tags` (array): For semantic retrieval
- `recall_count`: Usage tracking

**Conversations Table**
- Links User to Season
- One conversation per user per season

**Messages Table**
- `sender_type`: "user" or "ai"
- `content`: Message text
- `read_at`: Read receipt timestamp

**UserStates Table**
- `typing`: Typing indicator status
- `last_read_message_id`: Read tracking

**PushSubscriptions Table**
- Web Push API subscription data

**ToolStates Table**
- `tool_name`: Name of the persona tool (Calendar, Reminder, etc.)
- `state_data` (JSONB): Tool-specific state and data
- Links to Season for tool data persistence

**AiProviders Table**
- `provider_type`: AI provider name (e.g., 'gemini')
- `api_key`: Encrypted API key
- Configuration for AI provider selection

### Backend Architecture

**AI Services** (`app/services/ai/`)
- `BaseProvider`: Abstract AI provider interface
- `ProviderFactory`: Factory for creating AI provider instances
- `GeminiProvider` (in providers/): Gemini API implementation
- `PersonaGenerator`: Generate complete AI persona
- `MessageGenerator`: Generate message fragments
- `ActionDecider`: Decide AI actions (respond/wait/read_only/initiate)
- `TimingDecider`: Decide optimal timing for AI actions
- `StateEvolver`: Update context and emotions
- `NaturalEvolver`: Autonomous context evolution
- `FragmentReevaluator`: Reevaluate message fragments during sending
- `SystemContextBuilder`: Build system prompts with persona data

**Persona Tools** (`app/services/persona/tools/`)
- `BaseTool`: Abstract base class
- `ToolManager`: Orchestrates tool usage
- `ToolExecutorService`: Executes tool chains with conversation context
- 8 tools: Calendar, Reminder, Memo, Diary, Todo, Contacts, WebSearch, WebFetch

**Messaging Services** (`app/services/messaging/`)
- `ConversationHistoryFormatter`: Format conversation history for AI context
- `FragmentSenderService`: Send message fragments with delays
- `MessageBroadcastService`: Broadcast messages via ActionCable
- `ReadReceiptManagerService`: Track and update read status
- `TypingIndicatorService`: Manage typing status
- `NotificationService`: Trigger push notifications

**Season Services** (`app/services/season_services/`)
- `RotationManagerService`: Handle season rotation
- `DeactivationNotifierService`: Send warnings

**External Services** (`app/services/external/`)
- `WeatherService`: Fetch weather data
- `DuckduckgoService`: Web search
- `WebFetchService`: Fetch and parse web pages

**Memory Services** (`app/services/memory/`)
- `ManagementService`: Manage persona memory decay and relevance

**Analytics Services** (`app/services/analytics/`)
- `ActiveUsersService`: Track and count active users

**Utility Services** (`app/services/`)
- `DistributedLockManager`: Manage distributed locks for concurrent operations

**Background Jobs** (`app/jobs/`)
- `AiDecisionJob`: Decide next AI action
- `AiMessageGenerationJob`: Generate and send AI messages
- `AiStateEvolutionJob`: Evolve persona state based on events
- `NaturalEvolutionJob`: Autonomous periodic persona evolution
- `FragmentSendJob`: Send message fragments with realistic delays
- `MemoryManagementJob`: Manage persona memory decay and relevance
- `PeriodicTasksJob`: Hourly maintenance tasks
- `SeasonRotationJob`: Handle season rotation
- `SeasonDeactivationReminderJob`: Send rotation warnings
- `ActiveUsersUpdateJob`: Update active user counts

**API Controllers** (`app/controllers/api/v1/`)
- `AuthController`: Device-based authentication
- `AppStateController`: App state (season, users, version)
- `SeasonsController`: Season management
- `ConversationsController`: Conversation CRUD
- `MessagesController`: Message CRUD and read receipts
- `UserStatesController`: Typing status
- `UsersController`: User profile
- `ProfilesController`: AI and user profiles
- `SubscriptionsController`: Push notification subscriptions
- `DirectUploadsController`: ActiveStorage direct uploads

**ActionCable Channels** (`app/channels/`)
- `ConversationChannel`: Real-time messaging, typing, read receipts
- `AppStateChannel`: Real-time app state updates
- `ApplicationCable::Connection`: Device-based WebSocket auth

### Frontend Architecture

**Hooks** (`hooks/`)
- `useAuth`: Device-based authentication
- `useAppState`: App state management via WebSocket
- `useConversation`: Conversation and message management
- `useVisibility`: Page visibility detection
- `useIntersectionObserver`: Element visibility tracking
- `usePushNotifications`: Push notification management
- `useOnboarding`: First-run onboarding flow management
- `usePWAInstall`: PWA install prompt handling
- `useAppName`: Dynamic app name generation based on AI profile
- `useDocumentTitle`: Browser document title management
- `useAutoScroll`: Auto-scrolling with debouncing

**Components** (`components/`)
- `Loading/LoadingScreen`: Loading state
- `Header/ChatHeader`: App header with AI profile
- `Chat/MessageBubble`: Individual message component
- `Chat/TypingIndicator`: AI typing indicator
- `Chat/MessageList`: Scrollable message list
- `Chat/ChatInput`: Message input with auto-resize
- `Chat/ChatContainer`: Main chat container
- `Profile/ProfileModal`: Profile viewing/editing
- `Onboarding/OnboardingFlow`: First-run onboarding wizard
- `PWA/NotificationPrompt`: Push notification prompt
- `PWA/InstallPrompt`: PWA install prompt

**Services** (`lib/`)
- `api.ts`: REST API client
- `cable.ts`: ActionCable WebSocket client
- `utils.ts`: Utility functions (date formatting, etc.)
- `logger.ts`: Frontend logging utility
- `events.ts`: Event emitter for application events
- `constants.ts`: Application-wide constants

**Types** (`types/index.ts`)
- Complete TypeScript definitions for all data structures

### Real-Time Communication Flow

1. **User sends message**:
   - Frontend: `sendMessage()` → REST API
   - Backend: Create message → Broadcast via ActionCable
   - Frontend: Receive via WebSocket → Update UI
   - Backend: `AiDecisionJob` triggered

2. **AI decides action**:
   - `ActionDecider` analyzes conversation
   - Returns: `respond`, `wait`, `read_only`, or `initiate`
   - If `respond`: Queue `AiMessageGenerationJob`
   - If `wait`: Schedule `AiDecisionJob` for later

3. **AI sends message**:
   - `MessageGenerator` generates fragments
   - `FragmentSenderService` sends with typing indicators
   - Each fragment: Broadcast via ActionCable
   - Frontend: Real-time message display

4. **Read receipts**:
   - Frontend: IntersectionObserver + Visibility API
   - When message visible + page focused → REST API
   - Backend: Update `read_at` → Broadcast via ActionCable
   - Frontend: Remove "1" badge

### Deployment

**Backend** (Port 3001):
```bash
cd backend
bundle install
rails db:create db:migrate db:seed
redis-server  # For Sidekiq
bundle exec sidekiq  # Background jobs
rails server -p 3001
```

**Frontend** (Port 3000):
```bash
cd frontend
npm install
npm run dev
```

**Environment Variables**:
- Backend: `GEMINI_API_KEY` (or configure via database), `GEMINI_MODEL` (defaults to 'gemini-2.5-flash'), `AI_PROVIDER` (defaults to 'gemini'), `REDIS_URL`, `DATABASE_URL`, `VAPID_PRIVATE_KEY`, `VAPID_PUBLIC_KEY`, `APP_VERSION`
- Frontend: `NEXT_PUBLIC_API_URL`, `NEXT_PUBLIC_WS_URL`, `NEXT_PUBLIC_VAPID_PUBLIC_KEY`

## Implementation Status

### Completed Features ✅
- [x] **AI Provider Abstraction**: BaseProvider interface with GeminiProvider implementation, ProviderFactory for easy provider switching
- [x] **Database-backed AI Configuration**: AiProvider model stores provider type and API key (encrypted)
- [x] **Provider-agnostic AI Services**: All AI services use the abstraction layer
- [x] **AI Profile Evolution**: StateEvolver autonomously updates status_message based on conversations
- [x] **User Identifier in AI Context**: AI receives user's actual name instead of generic "상대방" to distinguish between different users in multi-user conversations
- [x] **Read-only Mode for Deactivated Seasons**: Chat input disabled, notice shown, backend prevents messaging
- [x] **Seasonal Rotation**: Automatic rotation every 3 months with ~2 weeks warning sent via normal message flow (not hardcoded)
- [x] **Multi-user Support**: Shared PersonaState, independent conversations per user
- [x] **Real-time Messaging**: ActionCable WebSocket for live updates
- [x] **Message Fragmentation**: Korean-style aggressive message breaking
- [x] **Read Receipts**: IntersectionObserver + Page Visibility API
- [x] **Typing Indicators**: Real-time typing status
- [x] **Push Notifications**: Web Push API integration
- [x] **PWA Support**: Service Worker, manifest.json
- [x] **Device-based Authentication**: No signup required
- [x] **Profile Management**: Users can edit profiles, AI autonomously updates status
- [x] **Tool System**: 8 persona tools for internal organization
- [x] **iOS-inspired UI**: Tailwind CSS with custom iOS theme
- [x] **First-run Onboarding Flow**: Multi-step onboarding with profile setup (name, status message, profile picture), notification permission, and PWA install prompt
- [x] **PWA Install Prompt**: beforeinstallprompt event handling with install banner
- [x] **Profile Picture Upload**: ActiveStorage with direct upload pattern, file upload UI in onboarding and profile modal

### Known Limitations
- AI profile picture generation: AI personas cannot autonomously change their profile pictures (only status_message is autonomously updated)
- Multiple AI providers: Only Gemini is implemented (architecture supports adding more)

## Testing Checklist
- [ ] Persona generation creates complete, realistic characters
- [ ] AI reads multiple unread messages at once
- [ ] AI doesn't reread already-read messages
- [ ] AI doesn't respond to its own messages
- [ ] AI can read messages without responding (읽씹 - read_only action)
- [ ] AI distinguishes between 읽씹 (read, ignored) and 안읽씹 (not read) emotionally and behaviorally
- [ ] Message fragmentation works naturally
- [ ] Dynamic fragment reevaluation during sending
- [ ] User can interrupt AI while typing
- [ ] AI-driven timing feels natural
- [ ] AI can choose not to respond
- [ ] Context and emotions evolve appropriately
- [ ] Web UI scrolling works smoothly
- [ ] Input stays at bottom and is always accessible
- [ ] Read receipts only mark messages as read when visible AND window focused
- [ ] Page visibility detection works correctly (focus in/out events)
- [ ] Push notifications trigger when new AI message arrives and user won't see it (unfocused OR scrolled up)
- [ ] Push notifications do NOT trigger when user is actively viewing conversation
- [ ] Typing indicator appears appropriately
- [ ] Auto-scroll to newest messages works
- [ ] No copyrighted terms in code
- [ ] Korean messaging patterns feel authentic
- [ ] No debugging logs remain in final code
