const { chromium } = require('playwright');
const { GoogleGenerativeAI } = require('@google/generative-ai');
const fs = require('fs');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '.env') });

const GEMINI_API_KEY = process.env.GEMINI_API_KEY;
const GEMINI_MODEL = process.env.GEMINI_MODEL || 'gemini-2.5-flash';

const IPHONE_WIDTH = 390;
const VIEWPORT_HEIGHT = 797; // 844 - 47 (status bar)

const OUTPUT_DIR = path.join(__dirname, '..', 'screenshots');

const genAI = new GoogleGenerativeAI(GEMINI_API_KEY);
const model = genAI.getGenerativeModel({ model: GEMINI_MODEL });

if (!fs.existsSync(OUTPUT_DIR)) {
  fs.mkdirSync(OUTPUT_DIR, { recursive: true });
}

const TIMING = {
  TYPING_SPEED_MIN: 60,
  TYPING_SPEED_MAX: 150,
  TYPING_VARIATION: 40,

  BEFORE_SEND_MIN: 500,
  BEFORE_SEND_MAX: 1500,

  FRAGMENT_DELAY_SHORT_MIN: 550,
  FRAGMENT_DELAY_SHORT_MAX: 1050,
  FRAGMENT_DELAY_MEDIUM_MIN: 1250,
  FRAGMENT_DELAY_MEDIUM_MAX: 1750,
  FRAGMENT_DELAY_LONG_MIN: 2250,
  FRAGMENT_DELAY_LONG_MAX: 2750,

  READING_SPEED_PER_CHAR: 50,
  READING_MIN: 800,
  READING_MAX: 5000,

  AFTER_SEND_MIN: 500,
  AFTER_SEND_MAX: 2000,

  AI_TYPING_FINISH_BUFFER: 1000,
  APP_LOAD_WAIT: 3000,
  ONBOARDING_STEP_DELAY: 2000,
  ONBOARDING_SKIP_DELAY: 1500,
  READ_ONLY_SCROLL_DELAY: 2000,

  TYPING_INDICATOR_TIMEOUT: 5000,
  AI_FINISH_TIMEOUT: 40000,
  CHAT_INTERFACE_TIMEOUT: 15000,
};

const REEVALUATION_PROBABILITY = 0.3;

const TARGET_SCREENSHOTS = 6;

const MESSAGE_PLACEHOLDER = '메시지';
const TYPING_INDICATOR = '입력 중';
const TIME_PATTERN = '오전|오후';

const MESSAGE_BUBBLE_CLASS = 'rounded-2xl';

const FRAGMENT_SIZE_SHORT = 10;
const FRAGMENT_SIZE_MEDIUM = 20;

const SEPARATOR = '='.repeat(60);

const USER_PERSONA = {
  name: '민수',
  age: 25,
  personality: 'Friendly, honest, expresses emotions naturally, enjoys keeping conversations going',
  communication_style: 'Sends short messages frequently, uses Korean internet slang often',
  current_mood: 'Normal and comfortable, interested in the conversation partner'
};

let conversationHistory = [];
let screenshotCount = 0;

function formatTimestamp(date) {
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  const hours = String(date.getHours()).padStart(2, '0');
  const minutes = String(date.getMinutes()).padStart(2, '0');
  return `${month}/${day} ${hours}:${minutes}`;
}

function formatConversationHistory(messages) {
  return messages.map(msg => {
    const timestamp = formatTimestamp(msg.timestamp);
    const readStatus = msg.read ? 'Read' : 'Unread';
    return `[${timestamp}] ${msg.sender}: ${msg.content} (${readStatus})`;
  }).join('\n');
}

async function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

function extractJsonFromResponse(responseText) {
  const jsonMatch = responseText.match(/\{[\s\S]*\}/);
  if (jsonMatch) {
    try {
      return JSON.parse(jsonMatch[0]);
    } catch (error) {
      console.error('   ❌ Failed to parse JSON:', error.message);
      return null;
    }
  }
  return null;
}

function parseKoreanTimestamp(timestampText) {
  const now = new Date();
  const match = timestampText.match(new RegExp(`(${TIME_PATTERN})\\s*(\\d+):(\\d+)`));

  if (match) {
    let hours = parseInt(match[2]);
    const minutes = parseInt(match[3]);

    if (match[1] === '오후' && hours !== 12) {
      hours += 12;
    } else if (match[1] === '오전' && hours === 12) {
      hours = 0;
    }

    const timestamp = new Date(now);
    timestamp.setHours(hours, minutes, 0, 0);
    return timestamp;
  }

  return now;
}

async function scrapeConversationFromPage(page) {
  const messages = [];

  const bubbles = await page.locator(`div[class*="${MESSAGE_BUBBLE_CLASS}"]`).all();

  for (const bubble of bubbles) {
    const content = await bubble.textContent();
    if (!content || content.includes(TYPING_INDICATOR)) continue;

    const classes = await bubble.getAttribute('class');
    const isUserMessage = classes && classes.includes('bg-primary');

    const parent = await bubble.locator('xpath=ancestor::div[contains(@class, "flex") and contains(@class, "mb-1.5")]').first();
    const timestampElement = await parent.locator(`text=/${TIME_PATTERN}/`).first();

    let timestamp = new Date();
    if (await timestampElement.count() > 0) {
      const timestampText = await timestampElement.textContent();
      timestamp = parseKoreanTimestamp(timestampText);
    }

    const hasUnreadBadge = isUserMessage && await parent.locator('text="1"').count() > 0;

    messages.push({
      sender: isUserMessage ? USER_PERSONA.name : 'AI',
      content: content.trim(),
      timestamp: timestamp,
      read: isUserMessage ? !hasUnreadBadge : false
    });
  }

  return messages;
}

function calculateConversationState() {
  const userMessages = conversationHistory.filter(m => m.sender === USER_PERSONA.name);
  const aiMessages = conversationHistory.filter(m => m.sender === 'AI');

  const unreadUserCount = aiMessages.filter(m => !m.read).length;
  const unreadAiCount = userMessages.filter(m => !m.read).length;

  return {
    unread_user_count: unreadUserCount,
    unread_ai_count: unreadAiCount,
    total_messages: conversationHistory.length
  };
}

function markAIMessagesAsRead() {
  conversationHistory.forEach(msg => {
    if (msg.sender === 'AI') {
      msg.read = true;
    }
  });
}

async function decideUserAction() {
  console.log('🤔 Deciding what to do...');

  const state = calculateConversationState();
  const historyText = conversationHistory.length === 0
    ? 'No messages yet'
    : formatConversationHistory(conversationHistory.slice(-20));

  const prompt = `You are ${USER_PERSONA.name}, a ${USER_PERSONA.age}-year-old Korean person.

Your personality: ${USER_PERSONA.personality}
Your communication style: ${USER_PERSONA.communication_style}
Current mood: ${USER_PERSONA.current_mood}

Current conversation history:
${historyText}

Unread messages from the other person: ${state.unread_user_count}
Your unread messages (messages you sent that they haven't read yet): ${state.unread_ai_count}

Based on your personality, emotional state, and the conversation context, decide what to do:
1. "respond" - Read and respond to unread messages now (ONLY if unread_count > 0)
2. "read_only" - Read messages but don't respond (읽씹) (ONLY if unread_count > 0)
3. "wait" - Wait before checking messages (specify how many seconds)
4. "initiate" - Start a new conversation (ONLY if unread_count == 0)

Consider:
- Your current emotional state
- Your personality traits
- How clingy or independent you are
- Whether you're busy or free
- The conversation flow
- Whether you WANT to talk right now

IMPORTANT - Understand the difference between two scenarios:
1. 안읽씹 (Unread): unread_ai_count > 0 means they haven't even opened the chat
   - Less personal/emotional: They might be busy, sleeping, phone off, or away
   - Natural interpretation: "They haven't seen it yet"
   - Response: Wait patiently (unless very clingy personality), don't spam messages

2. 읽씹 (Read but ignored): unread_ai_count == 0 AND they haven't replied
   - MORE personal/emotional: They READ your messages but chose not to respond
   - Possible meanings: Intentionally ignoring, upset/angry, need space, lost interest, being passive-aggressive
   - Your reaction depends on:
     * Personality: Anxious attachment = worried/hurt, secure = give space, avoidant = relieved
     * Context: After argument = probably upset, casual chat = might reply later
     * Relationship: Close = more hurt, distant = less affected
   - Behavior options: Give space, feel hurt/worried, initiate later if appropriate, or do read_only yourself as retaliation

- You can read messages without responding (read_only) when: upset, busy, not interested, need time to think, being passive-aggressive, etc.

Respond with ONLY a JSON object:
{
  "action": "respond" | "read_only" | "wait" | "initiate",
  "reason": "brief reason in Korean",
  "wait_seconds": 10-300 (only if action is wait)
}`;

  try {
    const result = await model.generateContent({
      contents: [{ role: 'user', parts: [{ text: prompt }] }],
      generationConfig: {
        temperature: 1.0,
        maxOutputTokens: 16384,
      },
    });

    if (result.response.promptFeedback && result.response.promptFeedback.blockReason) {
      return { action: 'wait', reason: 'Response blocked by safety filters', wait_seconds: 30 };
    }

    if (!result.response.candidates || result.response.candidates.length === 0) {
      return { action: 'wait', reason: 'No response candidates', wait_seconds: 30 };
    }

    const response = result.response.text().trim();
    const decision = extractJsonFromResponse(response);

    if (decision) {
      const actionEmojis = { respond: '📝', read_only: '👀', wait: '⏳', initiate: '🌟' };
      const emoji = actionEmojis[decision.action] || '❓';
      console.log(`   ${emoji} Action: ${decision.action} - ${decision.reason}`);
      if (decision.wait_seconds) {
        console.log(`   ⏳ Wait: ${decision.wait_seconds} seconds`);
      }
      return decision;
    }
  } catch (error) {
    console.error('   ❌ Error deciding action:', error.message);
  }

  return { action: 'wait', reason: 'Error', wait_seconds: 30 };
}

async function generateUserMessage() {
  console.log('💬 Generating user message...');

  const historyText = conversationHistory.length === 0
    ? 'No conversation yet'
    : formatConversationHistory(conversationHistory);

  const prompt = `You are ${USER_PERSONA.name}, a ${USER_PERSONA.age}-year-old Korean person.

Your personality: ${USER_PERSONA.personality}
Your communication style: ${USER_PERSONA.communication_style}
Current mood: ${USER_PERSONA.current_mood}

=== Conversation history so far ===
${historyText}

=== Your task ===
Analyze the conversation history above and generate natural next messages in Korean.

Conversation flow guide:
- If no conversation: Start with a light greeting
- If other person responded: Show interest, ask questions or empathize
- If conversation is ongoing: Share your own stories and deepen the conversation
- If conversation has gone on long enough: Naturally wrap up

Important rules:
1. Split your message into multiple short fragments like Koreans do in messaging apps
2. Each message should be short (usually 3-15 characters)
3. Use Korean internet slang (ㅋㅋㅋ, ㄱㅅ, ㅇㅋ, ㅠㅠ, etc.)
4. Be natural and genuine
5. Occasionally include typos or grammar mistakes for authenticity
6. Consider conversation flow for appropriate reactions

Output ONLY the message fragments in Korean, one per line. No JSON or other formatting.`;

  try {
    const result = await model.generateContent({
      contents: [{ role: 'user', parts: [{ text: prompt }] }],
      generationConfig: {
        temperature: 1.0,
        maxOutputTokens: 16384,
      },
    });

    if (result.response.promptFeedback && result.response.promptFeedback.blockReason) {
      return ['안녕'];
    }

    if (!result.response.candidates || result.response.candidates.length === 0) {
      return ['안녕'];
    }

    const response = result.response.text().trim();
    const fragments = response.split('\n').filter(f => f.trim().length > 0);

    console.log(`   Generated ${fragments.length} message fragments`);
    fragments.forEach((f, i) => console.log(`   [${i + 1}] "${f}"`));

    return fragments;
  } catch (error) {
    console.error('   ❌ Error generating message:', error.message);
    return ['안녕'];
  }
}

async function checkForAIInterruption(page) {
  const currentMessages = await scrapeConversationFromPage(page);
  const previousAICount = conversationHistory.filter(m => m.sender === 'AI').length;
  const currentAICount = currentMessages.filter(m => m.sender === 'AI').length;

  if (currentAICount > previousAICount) {
    const newAIMessages = currentMessages.filter(m => m.sender === 'AI').slice(previousAICount);

    conversationHistory = currentMessages;

    newAIMessages.forEach(msg => {
      console.log(`   ⚠️ AI interrupted: "${msg.content}"`);
    });

    return true;
  }

  return false;
}

async function reevaluateRemainingFragments(sentFragments, remainingFragments) {
  console.log('🔄 Reevaluating remaining user message fragments...');

  const recentHistory = formatConversationHistory(conversationHistory.slice(-10));
  const sentText = sentFragments.map(f => `${USER_PERSONA.name} (just sent): ${f}`).join('\n');
  const remainingText = remainingFragments.map(f => `[To be sent] ${f}`).join('\n');

  const prompt = `You are ${USER_PERSONA.name}, a ${USER_PERSONA.age}-year-old Korean person.

Your personality: ${USER_PERSONA.personality}
Your communication style: ${USER_PERSONA.communication_style}
Current mood: ${USER_PERSONA.current_mood}

=== Recent conversation state (last 10 messages) ===
${recentHistory}

=== Messages you just sent ===
${sentText}

=== Remaining messages you were planning to send ===
${remainingText}

Check if anything has changed (new messages from other person, conversation interrupted, etc.).

Should you:
1. Continue with remaining fragments as-is
2. Modify the remaining fragments
3. Stop sending (if other person interrupted or context changed)

Respond with ONLY a JSON object:
{
  "should_continue": true/false,
  "reason": "brief reason in Korean",
  "updated_fragments": ["array", "of", "messages"] or null if continuing as-is
}

If should_continue is false, you're stopping the current message sequence.
If updated_fragments is provided, use those instead of the original remaining fragments.`;

  try {
    const result = await model.generateContent({
      contents: [{ role: 'user', parts: [{ text: prompt }] }],
      generationConfig: {
        temperature: 0.7,
        maxOutputTokens: 16384,
      },
    });

    const response = result.response.text().trim();
    const decision = extractJsonFromResponse(response);

    if (decision) {
      console.log(`   Decision: ${decision.should_continue ? '✅ Continue' : '🛑 Stop'} - ${decision.reason}`);

      if (decision.updated_fragments && Array.isArray(decision.updated_fragments)) {
        console.log(`   📝 Updated ${decision.updated_fragments.length} fragments`);
      }

      return decision;
    }
  } catch (error) {
    console.error('   ❌ Error reevaluating fragments:', error.message);
  }

  return { should_continue: true, reason: 'Error', updated_fragments: null };
}

async function shouldContinueConversation() {
  console.log('🤔 AI deciding if conversation should continue...');

  const historyText = formatConversationHistory(conversationHistory);

  const prompt = `Analyze the following conversation history and decide if the conversation should continue:

${historyText}

Current state:
- Total messages exchanged: ${conversationHistory.length}
- Screenshots taken: ${screenshotCount}
- Target screenshots: ${TARGET_SCREENSHOTS}

Continue conversation when:
- Less than ${TARGET_SCREENSHOTS} screenshots taken
- Conversation hasn't progressed enough yet
- Haven't shown diverse conversation scenarios

Stop conversation when:
- All ${TARGET_SCREENSHOTS} screenshots taken
- Conversation has naturally concluded
- Sufficient diverse conversation patterns demonstrated

Respond with ONLY a JSON object:
{
  "should_continue": true or false,
  "reason": "brief reason"
}`;

  try {
    const result = await model.generateContent({
      contents: [{ role: 'user', parts: [{ text: prompt }] }],
      generationConfig: {
        temperature: 0.7,
        maxOutputTokens: 16384,
      },
    });

    const response = result.response.text().trim();
    const decision = extractJsonFromResponse(response);

    if (decision) {
      console.log(`   Decision: ${decision.should_continue ? '✅ Continue' : '🛑 Stop'} - ${decision.reason}`);
      return decision.should_continue;
    }
  } catch (error) {
    console.error('   ❌ Error deciding continuation:', error.message);
  }

  return screenshotCount < TARGET_SCREENSHOTS;
}

async function typeMessage(page, text) {
  const input = page.locator(`textarea[placeholder="${MESSAGE_PLACEHOLDER}"]`);
  await input.click();

  for (const char of text) {
    const baseDelay = TIMING.TYPING_SPEED_MIN + Math.random() * (TIMING.TYPING_SPEED_MAX - TIMING.TYPING_SPEED_MIN);
    const variation = Math.random() * TIMING.TYPING_VARIATION;
    await input.pressSequentially(char, { delay: baseDelay });
    await sleep(variation);
  }
}

function getFragmentDelay(fragmentLength) {
  let minDelay, maxDelay;
  if (fragmentLength <= FRAGMENT_SIZE_SHORT) {
    minDelay = TIMING.FRAGMENT_DELAY_SHORT_MIN;
    maxDelay = TIMING.FRAGMENT_DELAY_SHORT_MAX;
  } else if (fragmentLength <= FRAGMENT_SIZE_MEDIUM) {
    minDelay = TIMING.FRAGMENT_DELAY_MEDIUM_MIN;
    maxDelay = TIMING.FRAGMENT_DELAY_MEDIUM_MAX;
  } else {
    minDelay = TIMING.FRAGMENT_DELAY_LONG_MIN;
    maxDelay = TIMING.FRAGMENT_DELAY_LONG_MAX;
  }
  return minDelay + Math.random() * (maxDelay - minDelay);
}

function getReadingDelay(messages) {
  const totalChars = messages.reduce((sum, msg) => sum + msg.content.length, 0);
  const readingDelay = totalChars * TIMING.READING_SPEED_PER_CHAR;
  return Math.min(Math.max(readingDelay, TIMING.READING_MIN), TIMING.READING_MAX);
}

async function sendMessage(page, text) {
  await typeMessage(page, text);
  const reviewDelay = TIMING.BEFORE_SEND_MIN + Math.random() * (TIMING.BEFORE_SEND_MAX - TIMING.BEFORE_SEND_MIN);
  await sleep(reviewDelay);
  await page.keyboard.press('Enter');

  conversationHistory.push({
    sender: USER_PERSONA.name,
    content: text,
    timestamp: new Date(),
    read: false
  });
  console.log(`   📤 Sent: "${text}"`);
}

async function sendMessageFragments(page, fragments) {
  const sentFragments = [];
  let completed = true;

  for (let i = 0; i < fragments.length; i++) {
    const interrupted = await checkForAIInterruption(page);
    if (interrupted) {
      console.log('   🛑 AI interrupted before sending fragment, stopping');
      completed = false;
      break;
    }

    await sendMessage(page, fragments[i]);
    sentFragments.push(fragments[i]);

    const remainingCount = fragments.length - i - 1;
    const shouldReevaluate = remainingCount > 0 && Math.random() < REEVALUATION_PROBABILITY;

    if (shouldReevaluate) {
      const fragmentDelay = getFragmentDelay(fragments[i].length);
      await sleep(fragmentDelay);

      conversationHistory = await scrapeConversationFromPage(page);

      const remaining = fragments.slice(i + 1);
      const reevaluation = await reevaluateRemainingFragments(sentFragments, remaining);

      markAIMessagesAsRead();

      if (!reevaluation.should_continue) {
        console.log('   🛑 Reevaluation decided to stop sending');
        completed = false;
        break;
      }

      if (reevaluation.updated_fragments && Array.isArray(reevaluation.updated_fragments)) {
        console.log('   📝 Using updated fragments');
        fragments = [...sentFragments, ...reevaluation.updated_fragments];
      }
    } else if (remainingCount > 0) {
      const fragmentDelay = getFragmentDelay(fragments[i].length);
      await sleep(fragmentDelay);
    }
  }

  return { completed };
}

async function shouldTakeScreenshot() {
  if (screenshotCount >= TARGET_SCREENSHOTS) return { should_take: false };

  console.log('📸 Deciding if this is a good moment for screenshot...');

  const historyText = formatConversationHistory(conversationHistory);

  const prompt = `Review the following conversation history and determine if now is a good moment for a marketing screenshot:

${historyText}

Good moments for screenshots:
- Natural conversation flow is visible
- AI and user have exchanged several messages
- There's emotional connection or empathy
- Typing indicator is showing
- Conversation has reached an interesting point

Screenshots taken so far: ${screenshotCount}
Target screenshot count: 6

Respond with ONLY a JSON object:
{
  "should_take": true or false,
  "reason": "brief reason",
  "description": "screenshot description in English (e.g., 'Natural greeting exchange')"
}`;

  try {
    const result = await model.generateContent({
      contents: [{ role: 'user', parts: [{ text: prompt }] }],
      generationConfig: {
        temperature: 0.7,
        maxOutputTokens: 16384,
      },
    });

    const response = result.response.text().trim();
    const decision = extractJsonFromResponse(response);

    if (decision) {
      console.log(`   Decision: ${decision.should_take ? '✅ Yes' : '❌ No'} - ${decision.reason}`);
      return decision;
    }
  } catch (error) {
    console.error('   ❌ Error deciding screenshot:', error.message);
  }

  return { should_take: false, reason: 'Error', description: 'Screenshot' };
}

async function takeScreenshot(page, description) {
  screenshotCount++;
  const filename = `${String(screenshotCount).padStart(2, '0')}-${description.toLowerCase().replace(/\s+/g, '-')}.png`;

  console.log(`📸 Taking screenshot ${screenshotCount}/${TARGET_SCREENSHOTS}: ${description}`);
  const filepath = path.join(OUTPUT_DIR, filename);
  await page.screenshot({ path: filepath, fullPage: false });
  console.log(`✅ Saved: ${filepath}\n`);
}

async function waitForAITyping(page) {
  try {
    await page.waitForSelector(`text=/${TYPING_INDICATOR}/`, { timeout: TIMING.TYPING_INDICATOR_TIMEOUT });
    console.log('   🤖 AI started typing...');
    return true;
  } catch {
    return false;
  }
}

async function waitForAIFinish(page) {
  try {
    await page.waitForSelector(`text=/${TYPING_INDICATOR}/`, { state: 'hidden', timeout: TIMING.AI_FINISH_TIMEOUT });
    console.log('   ✅ AI finished typing');
    await sleep(TIMING.AI_TYPING_FINISH_BUFFER);
    return true;
  } catch {
    console.log('   ⚠️ AI typing timeout');
    return false;
  }
}

async function detectNewAIMessages(page) {
  const previousCount = conversationHistory.length;
  conversationHistory = await scrapeConversationFromPage(page);

  const newMessages = conversationHistory.slice(previousCount);
  const newAIMessages = newMessages.filter(m => m.sender === 'AI');

  if (newAIMessages.length > 0) {
    console.log('📨 New AI messages received:');
    newAIMessages.forEach(msg => {
      console.log(`   💬 AI: "${msg.content}"`);
    });
    return true;
  }

  return false;
}

async function main() {
  console.log('🚀 Starting screenshot automation (continuous mode)...');
  console.log(`📱 iPhone viewport: ${IPHONE_WIDTH}x${VIEWPORT_HEIGHT}`);
  console.log(`🎯 Goal: Generate 6 marketing screenshots through natural conversation\n`);

  const browser = await chromium.launch({ headless: true });

  const context = await browser.newContext({
    viewport: { width: IPHONE_WIDTH, height: VIEWPORT_HEIGHT },
    deviceScaleFactor: 3,
    isMobile: true,
    hasTouch: true,
    userAgent: 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15',
    timezoneId: 'Asia/Seoul'
  });

  const page = await context.newPage();

  console.log('🌐 Navigating to http://localhost:3000...');
  await page.goto('http://localhost:3000', { waitUntil: 'networkidle' });
  await sleep(TIMING.APP_LOAD_WAIT);
  console.log('✅ App loaded\n');

  console.log('🔍 Checking for onboarding...');
  const nextButton = page.locator('button:has-text("다음")');
  const onboardingExists = await nextButton.count() > 0;

  if (onboardingExists) {
    console.log('📝 Completing onboarding...');

    const nameInput = page.locator('input[placeholder*="이름"]');
    await nameInput.fill(USER_PERSONA.name);
    console.log(`   ✓ Name: ${USER_PERSONA.name}`);

    const statusInput = page.locator('input[placeholder*="상태 메시지"]');
    await statusInput.fill('오늘도 화이팅!');
    console.log('   ✓ Status message set');

    await nextButton.click();
    console.log('   ✓ Clicked next');
    await sleep(TIMING.ONBOARDING_STEP_DELAY);

    const skipButton = page.locator('button:has-text("건너뛰기"), button:has-text("나중에")');
    const skipExists = await skipButton.count();
    if (skipExists > 0) {
      await skipButton.first().click();
      console.log('   ✓ Skipped notification prompt');
      await sleep(TIMING.ONBOARDING_SKIP_DELAY);
    }

    const laterButton = page.locator('button:has-text("나중에")');
    const laterExists = await laterButton.count();
    if (laterExists > 0) {
      await laterButton.first().click();
      console.log('   ✓ Skipped PWA install prompt');
      await sleep(TIMING.ONBOARDING_SKIP_DELAY);
    }

    const startButton = page.locator('button:has-text("시작하기")');
    const startExists = await startButton.count();
    if (startExists > 0) {
      await startButton.click();
      console.log('   ✓ Clicked start button');
      await sleep(TIMING.ONBOARDING_STEP_DELAY);
    }

    console.log('✅ Onboarding completed\n');
  }

  console.log('⏳ Waiting for chat interface...');
  await page.locator(`textarea[placeholder="${MESSAGE_PLACEHOLDER}"]`).waitFor({ state: 'visible', timeout: TIMING.CHAT_INTERFACE_TIMEOUT });
  console.log('✅ Chat interface ready\n');

  let iterationCount = 0;
  const MAX_ITERATIONS = 50;

  while (iterationCount < MAX_ITERATIONS) {
    iterationCount++;
    console.log(`\n${SEPARATOR}`);
    console.log(`ITERATION ${iterationCount}`);
    console.log(SEPARATOR);

    await detectNewAIMessages(page);
    await page.evaluate(() => {
      const chatContainer = document.querySelector('.overflow-y-auto');
      if (chatContainer) {
        chatContainer.scrollTop = chatContainer.scrollHeight;
      }
    });
    await sleep(500);

    if (screenshotCount < TARGET_SCREENSHOTS && conversationHistory.length > 0) {
      const decision = await shouldTakeScreenshot();
      if (decision.should_take) {
        await takeScreenshot(page, decision.description);
      }
    }

    const decision = await decideUserAction();

    if (decision.action === 'respond') {
      console.log('📝 Action: Respond to messages\n');

      const unreadAIMessages = conversationHistory.filter(m => m.sender === 'AI' && !m.read);
      if (unreadAIMessages.length > 0) {
        const readingDelay = getReadingDelay(unreadAIMessages);
        console.log(`   📖 Reading ${unreadAIMessages.length} messages (${Math.round(readingDelay)}ms)`);
        await sleep(readingDelay);
      }

      markAIMessagesAsRead();

      const fragments = await generateUserMessage();
      await sendMessageFragments(page, fragments);

      const afterSendDelay = TIMING.AFTER_SEND_MIN + Math.random() * (TIMING.AFTER_SEND_MAX - TIMING.AFTER_SEND_MIN);
      await sleep(afterSendDelay);

      const aiTyping = await waitForAITyping(page);
      if (aiTyping) {
        await sleep(300);
        if (screenshotCount < TARGET_SCREENSHOTS) {
          console.log('   📸 Typing indicator detected!');
          const decision = await shouldTakeScreenshot();
          if (decision.should_take) {
            await takeScreenshot(page, decision.description);
          }
        }

        await waitForAIFinish(page);
        await detectNewAIMessages(page);

        if (screenshotCount < TARGET_SCREENSHOTS) {
          const decision = await shouldTakeScreenshot();
          if (decision.should_take) {
            await takeScreenshot(page, decision.description);
          }
        }
      }

    } else if (decision.action === 'read_only') {
      console.log('👀 Action: Read without responding\n');

      markAIMessagesAsRead();

      await page.evaluate(() => {
        const chatContainer = document.querySelector('.overflow-y-auto');
        if (chatContainer) {
          chatContainer.scrollTop = chatContainer.scrollHeight;
        }
      });
      await sleep(TIMING.READ_ONLY_SCROLL_DELAY);
      await detectNewAIMessages(page);

      if (screenshotCount < TARGET_SCREENSHOTS) {
        const decision = await shouldTakeScreenshot();
        if (decision.should_take) {
          await takeScreenshot(page, decision.description);
        }
      }

    } else if (decision.action === 'initiate') {
      console.log('🌟 Action: Initiate new conversation\n');

      const fragments = await generateUserMessage();
      await sendMessageFragments(page, fragments);

      const afterSendDelay = TIMING.AFTER_SEND_MIN + Math.random() * (TIMING.AFTER_SEND_MAX - TIMING.AFTER_SEND_MIN);
      await sleep(afterSendDelay);

      const aiTyping = await waitForAITyping(page);

      if (aiTyping) {
        await sleep(300);
        if (screenshotCount < TARGET_SCREENSHOTS) {
          console.log('   📸 Typing indicator detected!');
          const decision = await shouldTakeScreenshot();
          if (decision.should_take) {
            await takeScreenshot(page, decision.description);
          }
        }

        await waitForAIFinish(page);
        await detectNewAIMessages(page);

        if (screenshotCount < TARGET_SCREENSHOTS) {
          const decision = await shouldTakeScreenshot();
          if (decision.should_take) {
            await takeScreenshot(page, decision.description);
          }
        }
      }

    } else if (decision.action === 'wait') {
      const waitTime = decision.wait_seconds || 30;
      console.log(`⏳ Action: Wait for ${waitTime} seconds\n`);

      await sleep(waitTime * 1000);
      await detectNewAIMessages(page);

      if (screenshotCount < TARGET_SCREENSHOTS) {
        const decision = await shouldTakeScreenshot();
        if (decision.should_take) {
          await takeScreenshot(page, decision.description);
        }
      }
    }

    const shouldContinue = await shouldContinueConversation();

    if (!shouldContinue || screenshotCount >= TARGET_SCREENSHOTS) {
      console.log('\n🎉 Conversation goal reached!');
      break;
    }

    await sleep(2000);
  }

  console.log('\n' + SEPARATOR);
  console.log('✨ Screenshot automation complete!');
  console.log(SEPARATOR);
  console.log(`📁 Screenshots saved to: ${OUTPUT_DIR}`);
  console.log(`💬 Total messages exchanged: ${conversationHistory.length}`);
  console.log(`📸 Screenshots taken: ${screenshotCount}/${TARGET_SCREENSHOTS}`);
  console.log(`🔄 Iterations: ${iterationCount}`);

  await browser.close();
}

main().catch(error => {
  console.error('❌ Error:', error);
  process.exit(1);
});
