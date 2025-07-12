"use client"

import Link from "next/link"
import { usePathname } from "next/navigation"
import { useEffect, useState } from "react"
import { Moon, Sun } from "lucide-react"

const navItems = [
  { name: "Dashboard", href: "/" },
  { name: "Events", href: "/events" },
  { name: "Commands", href: "/commands" },
  { name: "Queries", href: "/queries" },
  { name: "Sagas", href: "/sagas" },
  { name: "PubSub", href: "/pubsub" },
  { name: "Topology", href: "/topology" },
]

export function Navigation() {
  const pathname = usePathname()
  const [currentTime, setCurrentTime] = useState<string>("")
  const [isDarkMode, setIsDarkMode] = useState<boolean>(true)

  useEffect(() => {
    const updateTime = () => {
      setCurrentTime(new Date().toLocaleTimeString())
    }
    
    updateTime()
    const interval = setInterval(updateTime, 1000)
    
    return () => clearInterval(interval)
  }, [])

  useEffect(() => {
    // 初回マウント時にダークモードの状態を確認
    const isDark = document.documentElement.classList.contains('dark')
    setIsDarkMode(isDark)
    
    // システム設定がダークモードの場合、クラスを追加
    if (window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches && !isDark) {
      document.documentElement.classList.add('dark')
      setIsDarkMode(true)
    }
  }, [])

  const toggleDarkMode = () => {
    const newMode = !isDarkMode
    setIsDarkMode(newMode)
    if (newMode) {
      document.documentElement.classList.add('dark')
    } else {
      document.documentElement.classList.remove('dark')
    }
  }

  return (
    <nav className="bg-white dark:bg-gray-900 text-gray-900 dark:text-white border-b border-gray-200 dark:border-gray-800">
      <div className="container mx-auto px-4">
        <div className="flex items-center justify-between h-16">
          <div className="flex items-center space-x-8">
            <h1 className="text-xl font-bold">CQRS/ES Monitor</h1>
            <div className="flex space-x-4">
              {navItems.map((item) => (
                <Link
                  key={item.name}
                  href={item.href}
                  className={`px-3 py-2 rounded-md text-sm font-medium transition-colors ${
                    pathname === item.href
                      ? "bg-gray-200 dark:bg-gray-700 text-gray-900 dark:text-white"
                      : "text-gray-700 dark:text-gray-300 hover:bg-gray-200 dark:hover:bg-gray-700 hover:text-gray-900 dark:hover:text-white"
                  }`}
                >
                  {item.name}
                </Link>
              ))}
            </div>
          </div>
          <div className="flex items-center space-x-4">
            <button
              onClick={toggleDarkMode}
              className="p-2 rounded-md hover:bg-gray-200 dark:hover:bg-gray-700 transition-colors"
              aria-label="Toggle dark mode"
            >
              {isDarkMode ? <Sun className="w-5 h-5" /> : <Moon className="w-5 h-5" />}
            </button>
            <span className="text-sm text-gray-600 dark:text-gray-400">{currentTime}</span>
          </div>
        </div>
      </div>
    </nav>
  )
}