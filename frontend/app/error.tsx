'use client';

import { useEffect } from 'react';

export default function Error({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    console.error('Error boundary caught:', error);
  }, [error]);

  return (
    <div className="flex min-h-screen items-center justify-center p-6">
      <div className="glass-card p-8 max-w-md w-full text-center space-y-6">
        <div className="space-y-2">
          <h2 className="text-2xl font-semibold text-gray-900">
            문제가 발생했습니다
          </h2>
          <p className="text-gray-600 text-sm">
            예상치 못한 오류가 발생했습니다.
          </p>
        </div>

        {process.env.NODE_ENV === 'development' && (
          <div className="bg-red-50 border border-red-200 rounded-lg p-4 text-left">
            <p className="text-xs font-mono text-red-800 break-all">
              {error.message}
            </p>
          </div>
        )}

        <div className="space-y-3">
          <button
            onClick={reset}
            className="w-full px-4 py-3 bg-primary-coral text-white font-medium rounded-xl
                     hover:bg-primary-coral/90 active:scale-98 transition-all shadow-glass-sm"
          >
            다시 시도
          </button>

          <button
            onClick={() => window.location.href = '/'}
            className="w-full px-4 py-3 bg-gray-100 text-gray-700 font-medium rounded-xl
                     hover:bg-gray-200 active:scale-98 transition-all"
          >
            홈으로 돌아가기
          </button>
        </div>
      </div>
    </div>
  );
}
