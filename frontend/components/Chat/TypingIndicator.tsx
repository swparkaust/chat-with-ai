import ProfilePicture from "@/components/Common/ProfilePicture";
import type { Season } from "@/types";

interface TypingIndicatorProps {
  season?: Season;
}

export default function TypingIndicator({ season }: TypingIndicatorProps) {
  return (
    <div className="flex mb-1.5 animate-scale-in justify-start">
      <div className="flex-shrink-0 w-8 h-8 mr-2">
        <ProfilePicture
          imageUrl={season?.profile_picture}
          size="xs"
          alt={season?.full_name ?? ""}
        />
      </div>

      <div className="flex flex-col max-w-[75%]">
        {season && (
          <span className="text-[12px] text-neutral-700 font-medium mb-1 px-1">
            {season.full_name}
          </span>
        )}

        <div className="px-3.5 py-3 rounded-2xl bg-neutral-100 shadow-sm flex items-center gap-1 mr-auto">
          <div className="flex gap-1">
            <div
              className="w-2 h-2 bg-neutral-400 rounded-full animate-bounce"
              style={{ animationDelay: "0ms", animationDuration: "1s" }}
            ></div>
            <div
              className="w-2 h-2 bg-neutral-400 rounded-full animate-bounce"
              style={{ animationDelay: "150ms", animationDuration: "1s" }}
            ></div>
            <div
              className="w-2 h-2 bg-neutral-400 rounded-full animate-bounce"
              style={{ animationDelay: "300ms", animationDuration: "1s" }}
            ></div>
          </div>
        </div>
      </div>
    </div>
  );
}
