"use client";

export default function ConversationDetailTemplate({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <div className="h-full w-full animate-push-enter">
      {children}
    </div>
  );
}
