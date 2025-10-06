'use client';

import { Menu } from 'lucide-react';
import Image from 'next/image';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import {
  NavigationMenu,
  NavigationMenuItem,
  NavigationMenuLink,
  NavigationMenuList,
  navigationMenuTriggerStyle,
} from '@/components/ui/navigation-menu';
import { Sheet, SheetContent, SheetTrigger } from '@/components/ui/sheet';
import { cn } from '@/lib/utils';

export function MainNav() {
  const pathname = usePathname();

  return (
    <div className="mr-4 flex w-full items-center justify-between">
      <div className="flex items-center space-x-2">
        <Link href="/" className="flex items-center space-x-2">
          <Image
            src="/images/logstruct.svg"
            alt="LogStruct Logo"
            width={32}
            height={32}
            className="mr-2"
          />
          <span className="font-bold text-xl leading-none">LogStruct</span>
        </Link>
        <a
          href="https://docspring.com"
          target="_blank"
          rel="noopener noreferrer"
          className="text-xs text-neutral-500 hover:text-neutral-700 dark:hover:text-neutral-300"
        >
          by DocSpring
        </a>
      </div>

      {/* Desktop Navigation */}
      <div className="hidden md:block">
        <NavigationMenu>
          <NavigationMenuList>
            <NavigationMenuItem>
              <Link href="/docs" legacyBehavior passHref>
                <NavigationMenuLink
                  className={navigationMenuTriggerStyle()}
                  active={pathname.startsWith('/docs')}
                >
                  Documentation
                </NavigationMenuLink>
              </Link>
            </NavigationMenuItem>
            <NavigationMenuItem>
              <a
                href="/yard/index.html"
                target="_blank"
                rel="noopener noreferrer"
                className={navigationMenuTriggerStyle()}
              >
                YARD Docs
              </a>
            </NavigationMenuItem>
            <NavigationMenuItem>
              <a
                href="https://github.com/DocSpring/logstruct"
                target="_blank"
                rel="noopener noreferrer"
                className={navigationMenuTriggerStyle()}
              >
                GitHub
              </a>
            </NavigationMenuItem>
          </NavigationMenuList>
        </NavigationMenu>
      </div>

      {/* Mobile Navigation */}
      <div className="md:hidden">
        <Sheet>
          <SheetTrigger className="flex items-center justify-center rounded-md p-2 text-neutral-500 hover:bg-neutral-100 hover:text-neutral-900 dark:text-neutral-300 dark:hover:bg-neutral-800 dark:hover:text-neutral-50">
            <Menu className="h-6 w-6" />
            <span className="sr-only">Toggle menu</span>
          </SheetTrigger>
          <SheetContent side="right" className="w-[280px] p-0">
            <div className="flex flex-col gap-4 p-6">
              <div className="flex items-center space-x-2">
                <Link href="/" className="flex items-center space-x-2">
                  <Image src="/images/logstruct.svg" alt="LogStruct Logo" width={28} height={28} />
                  <span className="font-bold text-xl leading-none">LogStruct</span>
                </Link>
                <a
                  href="https://docspring.com"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="text-xs text-neutral-500 hover:text-neutral-700 dark:hover:text-neutral-300"
                >
                  by DocSpring
                </a>
              </div>
              <div className="flex flex-col gap-3 mt-4">
                <Link
                  href="/docs"
                  className={cn(
                    'text-lg font-medium',
                    pathname.startsWith('/docs') && 'text-neutral-900 dark:text-neutral-50',
                  )}
                >
                  Documentation
                </Link>
                <Link
                  href="/docs/getting-started"
                  className="text-base text-neutral-600 dark:text-neutral-300"
                >
                  Getting Started
                </Link>
                <Link
                  href="/docs/configuration"
                  className="text-base text-neutral-600 dark:text-neutral-300"
                >
                  Configuration
                </Link>
                <Link
                  href="/docs/integrations"
                  className="text-base text-neutral-600 dark:text-neutral-300"
                >
                  Integrations
                </Link>
                <Link
                  href="/docs/sorbet-types"
                  className="text-base text-neutral-600 dark:text-neutral-300"
                >
                  Type Safety
                </Link>
                <a
                  href="/yard/index.html"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="text-lg font-medium mt-2"
                >
                  YARD Docs
                </a>
                <a
                  href="https://github.com/DocSpring/logstruct"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="text-lg font-medium"
                >
                  GitHub
                </a>
              </div>
            </div>
          </SheetContent>
        </Sheet>
      </div>
    </div>
  );
}
