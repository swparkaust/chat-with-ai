import { User } from "lucide-react";

interface ProfilePictureProps {
  imageUrl?: string | null;
  size?: "xs" | "sm" | "md" | "lg" | "xl";
  className?: string;
  alt?: string;
}

const sizeClasses = {
  xs: "w-8 h-8",
  sm: "w-10 h-10",
  md: "w-14 h-14",
  lg: "w-20 h-20",
  xl: "w-32 h-32",
};

const iconSizes = {
  xs: 16,
  sm: 20,
  md: 28,
  lg: 40,
  xl: 64,
};

export default function ProfilePicture({
  imageUrl,
  size = "md",
  className = "",
  alt = "",
}: ProfilePictureProps) {
  const sizeClass = sizeClasses[size];
  const iconSize = iconSizes[size];

  return (
    <div
      className={`${sizeClass} rounded-full bg-neutral-300 flex items-center justify-center overflow-hidden shadow-sm ${className}`}
    >
      {imageUrl ? (
        <img
          src={imageUrl}
          alt={alt}
          className="w-full h-full object-cover"
        />
      ) : (
        <User size={iconSize} className="text-white" strokeWidth={2} />
      )}
    </div>
  );
}
