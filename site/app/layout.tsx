import type { Metadata } from 'next';
import { Geist, Geist_Mono } from 'next/font/google';
import Script from 'next/script';
import './globals.css';
import { MainNav } from '@/components/main-nav';
import { EmptyNav } from '@/components/empty-nav';
import { SiteFooter } from '@/components/site-footer';
import { ThemeProvider } from '@/components/theme-provider';
import { isComingSoon } from '@/lib/config';
import ComingSoonContent from './coming-soon';

const geistSans = Geist({
  variable: '--font-geist-sans',
  subsets: ['latin'],
});

const geistMono = Geist_Mono({
  variable: '--font-geist-mono',
  subsets: ['latin'],
});

export const metadata: Metadata = {
  title: 'LogStruct - Zero-configuration JSON Logging for Ruby on Rails',
  description:
    'Type-safe JSON structured logging for Rails apps with support for Sidekiq, Shrine, ActiveStorage, CarrierWave, and more.',
  keywords: [
    'Rails',
    'Ruby',
    'logging',
    'JSON',
    'structured logging',
    'Sidekiq',
    'Sorbet',
    'TypeScript',
  ],
  icons: {
    icon: [
      { url: '/favicon.ico' },
      { url: '/favicon.png' },
    ]
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" suppressHydrationWarning className="scroll-smooth">
      <body
        className={`${geistSans.variable} ${geistMono.variable} antialiased min-h-screen`}
      >
        <Script
          defer
          data-domain="logstruct.com"
          src="https://pa.docspring.com/js/script.js"
          strategy="afterInteractive"
        />
        <ThemeProvider>
          <div className="relative flex min-h-screen flex-col bg-white dark:bg-neutral-950">
            <header className="sticky top-0 z-50 w-full border-b border-neutral-200 bg-white dark:border-neutral-800 dark:bg-neutral-950">
              <div className="container flex h-16 items-center px-4 sm:px-6 lg:px-8">
                {isComingSoon ? <EmptyNav /> : <MainNav />}
              </div>
            </header>
            <main className="flex-1">
              {isComingSoon ? <ComingSoonContent /> : children}
            </main>
            <SiteFooter />
          </div>
        </ThemeProvider>
      </body>
    </html>
  );
}
