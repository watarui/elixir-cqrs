import type { Metadata } from "next"
import { Navigation } from "@/components/navigation"
import { Providers } from "@/components/providers"
import "./globals.css"

export const metadata: Metadata = {
  title: "CQRS/ES Monitor Dashboard",
  description: "Real-time monitoring for CQRS Event Sourcing system",
}

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode
}>) {
  return (
    <html lang="en">
      <body className="antialiased">
        <Providers>
          <Navigation />
          <div className="min-h-screen bg-gray-50 dark:bg-gray-900">
            {children}
          </div>
        </Providers>
      </body>
    </html>
  )
}