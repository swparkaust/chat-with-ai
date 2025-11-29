type EventCallback = (data?: unknown) => void;

class EventEmitter {
  private events: Map<string, Set<EventCallback>> = new Map();

  on(event: string, callback: EventCallback) {
    if (!this.events.has(event)) {
      this.events.set(event, new Set());
    }
    this.events.get(event)!.add(callback);
  }

  off(event: string, callback: EventCallback) {
    this.events.get(event)?.delete(callback);
  }

  emit(event: string, data?: unknown) {
    this.events.get(event)?.forEach(callback => callback(data));
  }

  // Helper to wait for a specific event once
  once(event: string): Promise<unknown> {
    return new Promise((resolve) => {
      const callback = (data: unknown) => {
        this.off(event, callback);
        resolve(data);
      };
      this.on(event, callback);
    });
  }
}

export const authEvents = new EventEmitter();
