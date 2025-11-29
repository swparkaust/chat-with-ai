"use client";

export default function ConversationsTemplate({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <div className="h-full w-full animate-pop-enter">
      {children}
    </div>
  );
}
