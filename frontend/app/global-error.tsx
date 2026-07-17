'use client';

import { useEffect } from 'react';

export default function GlobalError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    console.error('Global error boundary caught:', error);
  }, [error]);

  return (
    <html lang="ko">
      <body>
        <div className="flex min-h-screen items-center justify-center p-6 bg-gradient-to-br from-neutral-50 via-primary-coral/5 to-primary-purple/5">
          <div className="glass-card p-8 max-w-md w-full text-center space-y-6">
            <div className="space-y-2">
              <h2 className="text-2xl font-semibold text-gray-900">
                치명적인 오류가 발생했습니다
              </h2>
              <p className="text-gray-600 text-sm">
                앱을 다시 시작해야 합니다.
              </p>
            </div>

            {process.env.NODE_ENV === 'development' && (
              <div className="bg-red-50 border border-red-200 rounded-lg p-4 text-left">
                <p className="text-xs font-mono text-red-800 break-all">
                  {error.message}
                </p>
              </div>
            )}

            <button
              onClick={reset}
              className="w-full px-4 py-3 bg-primary-coral text-white font-medium rounded-xl
                       hover:bg-primary-coral/90 active:scale-98 transition-all shadow-glass-sm"
            >
              앱 다시 시작
            </button>
          </div>
        </div>
      </body>
    </html>
  );
}
