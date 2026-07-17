import type { Metadata, Viewport } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "○○와 채팅하기",
  description: "자연스러운 대화를 나눠보세요",
  manifest: "/manifest.json",
  appleWebApp: {
    capable: true,
    statusBarStyle: "default",
    title: "○○와 채팅하기",
  },
  formatDetection: {
    telephone: false,
  },
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  maximumScale: 1,
  userScalable: false,
  viewportFit: "cover",
  themeColor: "#FF6B81",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="ko" className="h-full">
      <head>
        <link rel="icon" href="/favicon.ico" />
        <link rel="apple-touch-icon" href="/icon-192x192.png" />
      </head>
      <body className="antialiased h-full bg-gradient-to-br from-neutral-50 via-primary-coral/5 to-primary-purple/5">
        <div className="fixed inset-0 bg-gradient-to-br from-transparent via-primary-coral/3 to-primary-purple/3 pointer-events-none -z-10"></div>
        {children}
      </body>
    </html>
  );
}
