import type { ReactNode } from "react";
import "./globals.css";

export const metadata = {
  title: "Todo Web App",
  description: "A small Todo app example built with agentic framework."
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}


