export default function LoadingScreen() {
  return (
    <div className="flex items-center justify-center h-full w-full bg-gradient-to-b from-neutral-50 to-white">
      <div className="flex flex-col items-center gap-4 animate-scale-in">
        <div className="relative w-16 h-16">
          <div className="absolute top-0 left-0 w-full h-full rounded-full border-[3px] border-neutral-200"></div>
          <div className="absolute top-0 left-0 w-full h-full rounded-full border-[3px] border-primary-coral border-t-transparent animate-spin"></div>
        </div>
        <div className="text-center">
          <p className="text-neutral-600 text-sm">잠시만 기다려주세요...</p>
        </div>
      </div>
    </div>
  );
}
