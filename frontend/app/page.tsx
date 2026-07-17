"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";
import LoadingScreen from "@/components/Loading/LoadingScreen";

export default function Home() {
  const router = useRouter();

  useEffect(() => {
    router.replace("/conversations");
  }, [router]);

  return <LoadingScreen />;
}
