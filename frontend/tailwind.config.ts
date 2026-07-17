import type { Config } from "tailwindcss";

const config: Config = {
  content: [
    "./pages/**/*.{js,ts,jsx,tsx,mdx}",
    "./components/**/*.{js,ts,jsx,tsx,mdx}",
    "./app/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: {
    extend: {
      colors: {
        primary: {
          coral: "#FF6B81",
          blue: "#007AFF",
          green: "#34C759",
          indigo: "#5856D6",
          orange: "#FF9500",
          pink: "#FF2D55",
          purple: "#AF52DE",
          red: "#FF3B30",
          teal: "#5AC8FA",
          yellow: "#FFCC00",
        },
        neutral: {
          50: "#F2F2F7",
          100: "#E5E5EA",
          200: "#D1D1D6",
          300: "#C7C7CC",
          400: "#AEAEB2",
          500: "#8E8E93",
          600: "#636366",
          700: "#48484A",
          800: "#3A3A3C",
          900: "#2C2C2E",
          950: "#1C1C1E",
        },
        glass: {
          light: "rgba(255, 255, 255, 0.15)",
          lighter: "rgba(255, 255, 255, 0.1)",
          lightest: "rgba(255, 255, 255, 0.05)",
          dark: "rgba(0, 0, 0, 0.15)",
          darker: "rgba(0, 0, 0, 0.2)",
          blue: "rgba(0, 122, 255, 0.15)",
          blueStrong: "rgba(0, 122, 255, 0.25)",
          coral: "rgba(255, 107, 129, 0.15)",
          coralStrong: "rgba(255, 107, 129, 0.25)",
        },
        bubble: {
          user: "#FF6B81",
          ai: "rgba(229, 229, 234, 0.85)",
        },
      },
      fontFamily: {
        sans: [
          "-apple-system",
          "BlinkMacSystemFont",
          "Segoe UI",
          "Roboto",
          "Helvetica Neue",
          "Arial",
          "sans-serif",
        ],
      },
      fontSize: {
        xs: ["11px", { lineHeight: "16px", fontWeight: "400" }],
        sm: ["13px", { lineHeight: "18px", fontWeight: "400" }],
        base: ["15px", { lineHeight: "20px", fontWeight: "400" }],
        lg: ["17px", { lineHeight: "22px", fontWeight: "500" }],
        xl: ["19px", { lineHeight: "24px", fontWeight: "600" }],
        "2xl": ["22px", { lineHeight: "28px", fontWeight: "600" }],
        "3xl": ["28px", { lineHeight: "34px", fontWeight: "700" }],
      },
      fontWeight: {
        regular: "400",
        medium: "500",
        semibold: "600",
        bold: "700",
      },
      borderRadius: {
        card: "12px",
        bubble: "20px",
        glass: "24px",
      },
      boxShadow: {
        soft: "0 1px 3px rgba(0, 0, 0, 0.12), 0 1px 2px rgba(0, 0, 0, 0.24)",
        card: "0 2px 8px rgba(0, 0, 0, 0.1)",
        glass: "0 8px 32px rgba(31, 38, 135, 0.2), inset 0 4px 20px rgba(255, 255, 255, 0.3)",
        "glass-sm": "0 4px 16px rgba(31, 38, 135, 0.15), inset 0 2px 10px rgba(255, 255, 255, 0.25)",
        "glass-lg": "0 12px 48px rgba(31, 38, 135, 0.25), inset 0 6px 30px rgba(255, 255, 255, 0.35)",
        specular: "inset -10px -8px 0px -11px rgba(255, 255, 255, 1), inset 0px -9px 0px -8px rgba(255, 255, 255, 1)",
        elevated: "0 4px 16px rgba(0, 0, 0, 0.08)",
        "elevated-lg": "0 8px 24px rgba(0, 0, 0, 0.12)",
      },
      backdropBlur: {
        xs: "2px",
        sm: "4px",
        DEFAULT: "8px",
        md: "12px",
        lg: "16px",
        xl: "24px",
        "2xl": "40px",
        "3xl": "64px",
      },
      backdropSaturate: {
        150: "1.5",
        180: "1.8",
        200: "2",
      },
      transitionTimingFunction: {
        spring: "cubic-bezier(0.68, -0.55, 0.27, 1.55)",
        smooth: "cubic-bezier(0.4, 0, 0.2, 1)",
        "native-ease": "cubic-bezier(0.32, 0.72, 0, 1)",
      },
      transitionDuration: {
        "350": "350ms",
      },
      animation: {
        shimmer: "shimmer 2s ease-in-out infinite",
        float: "float 3s ease-in-out infinite",
        "scale-in": "scale-in 0.2s cubic-bezier(0.68, -0.55, 0.27, 1.55)",
        "slide-up": "slide-up 0.3s cubic-bezier(0.4, 0, 0.2, 1)",
        "slide-down": "slide-down 0.3s cubic-bezier(0.4, 0, 0.2, 1)",
        "slide-right": "slide-right 0.3s cubic-bezier(0.4, 0, 0.2, 1)",
        "slide-left": "slide-left 0.3s cubic-bezier(0.4, 0, 0.2, 1)",
        "fade-in": "fade-in 0.2s ease-out",
        "fade-out": "fade-out 0.2s ease-in",
        pulse: "pulse 2s cubic-bezier(0.4, 0, 0.6, 1) infinite",
        bounce: "bounce 1s infinite",
        "push-enter": "push-enter 350ms cubic-bezier(0.32, 0.72, 0, 1)",
        "push-exit": "push-exit 350ms cubic-bezier(0.32, 0.72, 0, 1)",
        "pop-enter": "pop-enter 350ms cubic-bezier(0.32, 0.72, 0, 1)",
        "pop-exit": "pop-exit 350ms cubic-bezier(0.32, 0.72, 0, 1)",
        "modal-enter": "modal-enter 350ms cubic-bezier(0.32, 0.72, 0, 1)",
        "modal-exit": "modal-exit 250ms cubic-bezier(0.4, 0.0, 1, 1)",
      },
      keyframes: {
        shimmer: {
          "0%, 100%": { opacity: "0.6" },
          "50%": { opacity: "0.8" },
        },
        float: {
          "0%, 100%": { transform: "translateY(0px)" },
          "50%": { transform: "translateY(-4px)" },
        },
        "scale-in": {
          "0%": { transform: "scale(0.95)", opacity: "0" },
          "100%": { transform: "scale(1)", opacity: "1" },
        },
        "slide-up": {
          "0%": { transform: "translateY(100%)", opacity: "0" },
          "100%": { transform: "translateY(0)", opacity: "1" },
        },
        "slide-down": {
          "0%": { transform: "translateY(-100%)", opacity: "0" },
          "100%": { transform: "translateY(0)", opacity: "1" },
        },
        "slide-right": {
          "0%": { transform: "translateX(-100%)", opacity: "0" },
          "100%": { transform: "translateX(0)", opacity: "1" },
        },
        "slide-left": {
          "0%": { transform: "translateX(100%)", opacity: "0" },
          "100%": { transform: "translateX(0)", opacity: "1" },
        },
        "fade-in": {
          "0%": { opacity: "0" },
          "100%": { opacity: "1" },
        },
        "fade-out": {
          "0%": { opacity: "1" },
          "100%": { opacity: "0" },
        },
        pulse: {
          "0%, 100%": { opacity: "1" },
          "50%": { opacity: "0.5" },
        },
        bounce: {
          "0%, 100%": {
            transform: "translateY(-25%)",
            animationTimingFunction: "cubic-bezier(0.8, 0, 1, 1)",
          },
          "50%": {
            transform: "translateY(0)",
            animationTimingFunction: "cubic-bezier(0, 0, 0.2, 1)",
          },
        },
        "push-enter": {
          "0%": { transform: "translateX(100%)" },
          "100%": { transform: "translateX(0)" },
        },
        "push-exit": {
          "0%": { transform: "translateX(0)" },
          "100%": { transform: "translateX(-30%)" },
        },
        "pop-enter": {
          "0%": { transform: "translateX(-30%)" },
          "100%": { transform: "translateX(0)" },
        },
        "pop-exit": {
          "0%": { transform: "translateX(0)" },
          "100%": { transform: "translateX(100%)" },
        },
        "modal-enter": {
          "0%": { transform: "translateY(100%)" },
          "100%": { transform: "translateY(0)" },
        },
        "modal-exit": {
          "0%": { transform: "translateY(0)" },
          "100%": { transform: "translateY(100%)" },
        },
      },
    },
  },
  plugins: [],
};

export default config;
