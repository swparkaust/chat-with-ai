import Link from "next/link";

interface ErrorCardProps {
  title: string;
  message: string | null;
  onRetry?: () => void;
  backHref?: string;
  backLabel?: string;
}

export default function ErrorCard({
  title,
  message,
  onRetry,
  backHref,
  backLabel = "돌아가기",
}: ErrorCardProps) {
  return (
    <div className="flex items-center justify-center h-full p-4">
      <div className="text-center bg-white rounded-2xl shadow-elevated p-6 max-w-sm">
        <p className="text-primary-red mb-2 font-semibold">{title}</p>
        <p className="text-sm text-neutral-600">{message}</p>
        {(onRetry || backHref) && (
          <div className="mt-4 flex justify-center gap-2">
            {onRetry && (
              <button
                onClick={onRetry}
                className="px-5 py-2.5 bg-primary-coral text-white rounded-full text-sm font-medium active:opacity-80 transition-opacity"
              >
                다시 시도
              </button>
            )}
            {backHref && (
              <Link
                href={backHref}
                className="px-5 py-2.5 bg-white border border-neutral-200 rounded-full text-sm font-medium text-neutral-700 active:bg-neutral-50 transition-colors"
              >
                {backLabel}
              </Link>
            )}
          </div>
        )}
      </div>
    </div>
  );
}
