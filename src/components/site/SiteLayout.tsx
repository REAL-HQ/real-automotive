import type { ReactNode } from "react";
import { Nav } from "./Nav";
import { Footer } from "./Footer";

export function SiteLayout({ children, hideNav }: { children: ReactNode; hideNav?: boolean }) {
  return (
    <div className="min-h-screen flex flex-col bg-background">
      {!hideNav && <Nav />}
      <main className="flex-1">{children}</main>
      <Footer />
    </div>
  );
}