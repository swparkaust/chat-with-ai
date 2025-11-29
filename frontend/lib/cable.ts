import { createConsumer, Consumer, Subscription } from "@rails/actioncable";

const WS_URL =
  process.env.NEXT_PUBLIC_WS_URL ?? "ws://localhost:3001/cable";

let consumer: Consumer | null = null;

export function getConsumer(deviceId: string): Consumer {
  if (!consumer) {
    consumer = createConsumer(`${WS_URL}?device_id=${deviceId}`);
  }
  return consumer;
}

export function disconnectConsumer() {
  if (consumer) {
    consumer.disconnect();
    consumer = null;
  }
}

export interface ChannelCallbacks {
  connected?: () => void;
  disconnected?: () => void;
  received?: (data: unknown) => void;
  rejected?: () => void;
}

export function subscribeToChannel(
  deviceId: string,
  channel: string,
  params: object = {},
  callbacks: ChannelCallbacks = {}
): Subscription {
  const cable = getConsumer(deviceId);

  return cable.subscriptions.create(
    {
      channel,
      ...params,
    },
    {
      connected() {
        callbacks.connected?.();
      },
      disconnected() {
        callbacks.disconnected?.();
      },
      received(data: unknown) {
        callbacks.received?.(data);
      },
      rejected() {
        callbacks.rejected?.();
      },
    }
  );
}

export function unsubscribeFromChannel(subscription: Subscription) {
  if (subscription) {
    subscription.unsubscribe();
  }
}
