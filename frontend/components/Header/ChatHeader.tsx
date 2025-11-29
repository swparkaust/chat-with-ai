"use client";

import { useRouter } from "next/navigation";
import { ChevronLeft } from "lucide-react";
import ProfilePicture from "@/components/Common/ProfilePicture";
import type { Season } from "@/types";

interface ChatHeaderProps {
  season?: Season | null;
  onProfileClick?: () => void;
}

export default function ChatHeader({ season, onProfileClick }: ChatHeaderProps) {
  const router = useRouter();
  const firstName = season?.first_name ?? "";

  const handleBackClick = () => {
    router.push("/conversations");
  };

  return (
    <header className="sticky top-0 z-10 bg-white/80 backdrop-blur-xl border-b border-neutral-200/60">
      <div className="px-4 h-14 flex items-center gap-3">
        <button
          onClick={handleBackClick}
          className="flex-shrink-0 w-9 h-9 flex items-center justify-center text-primary-coral active:opacity-60 transition-opacity -ml-2"
        >
          <ChevronLeft size={24} strokeWidth={2.5} />
        </button>

        <div
          className="flex-1 flex items-center gap-3 cursor-pointer active:opacity-80 transition-opacity min-w-0"
          onClick={onProfileClick}
        >
          <ProfilePicture
            imageUrl={season?.profile_picture}
            size="sm"
            alt={season?.full_name ?? ""}
            className="flex-shrink-0"
          />

          <div className="flex-1 min-w-0">
            <h1 className="text-base font-semibold text-neutral-900 truncate">{season?.full_name ?? ""}</h1>
            {season?.status_message && (
              <p className="text-xs text-neutral-500 truncate">
                {season.status_message}
              </p>
            )}
          </div>
        </div>
      </div>
    </header>
  );
}
