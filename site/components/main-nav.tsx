"use client";

import Link from "next/link";
import { useState } from "react";
import { usePathname } from "next/navigation";
import { Menu, X } from "lucide-react";
import { NavigationMenu, NavigationMenuContent, NavigationMenuItem, NavigationMenuLink, NavigationMenuList, NavigationMenuTrigger, navigationMenuTriggerStyle } from "@/components/ui/navigation-menu";
import { Sheet, SheetContent, SheetTrigger } from "@/components/ui/sheet";
import { cn } from "@/lib/utils";

export function MainNav() {
  const pathname = usePathname();
  
  return (
    <div className="mr-4 flex w-full items-center justify-between">
      <Link href="/" className="flex items-center space-x-2">
        <span className="font-bold text-xl">LogStruct</span>
        <span className="text-xs text-neutral-500">by DocSpring</span>
      </Link>
      
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
              <NavigationMenuTrigger>Guides</NavigationMenuTrigger>
              <NavigationMenuContent>
                <ul className="grid gap-3 p-4 md:w-[400px] lg:w-[500px] lg:grid-cols-[.75fr_1fr]">
                  <li className="row-span-3">
                    <NavigationMenuLink asChild>
                      <a
                        className="flex h-full w-full select-none flex-col justify-end rounded-md bg-gradient-to-b from-neutral-900 to-neutral-700 p-6 no-underline outline-none focus:shadow-md"
                        href="/docs/getting-started"
                      >
                        <div className="mt-4 mb-2 text-lg font-medium text-white">
                          Getting Started
                        </div>
                        <p className="text-sm leading-tight text-white/90">
                          Quick setup guide for adding LogStruct to your Rails application
                        </p>
                      </a>
                    </NavigationMenuLink>
                  </li>
                  <li>
                    <NavigationMenuLink asChild>
                      <a
                        href="/docs/configuration"
                        className="block select-none space-y-1 rounded-md p-3 leading-none no-underline outline-none transition-colors hover:bg-neutral-100 focus:bg-neutral-100 dark:hover:bg-neutral-800 dark:focus:bg-neutral-800"
                      >
                        <div className="text-sm font-medium leading-none">
                          Configuration
                        </div>
                        <p className="line-clamp-2 text-sm leading-snug text-neutral-500 dark:text-neutral-400">
                          Learn how to configure LogStruct for your application
                        </p>
                      </a>
                    </NavigationMenuLink>
                  </li>
                  <li>
                    <NavigationMenuLink asChild>
                      <a
                        href="/docs/integrations"
                        className="block select-none space-y-1 rounded-md p-3 leading-none no-underline outline-none transition-colors hover:bg-neutral-100 focus:bg-neutral-100 dark:hover:bg-neutral-800 dark:focus:bg-neutral-800"
                      >
                        <div className="text-sm font-medium leading-none">
                          Integrations
                        </div>
                        <p className="line-clamp-2 text-sm leading-snug text-neutral-500 dark:text-neutral-400">
                          Explore the built-in integrations with popular gems
                        </p>
                      </a>
                    </NavigationMenuLink>
                  </li>
                  <li>
                    <NavigationMenuLink asChild>
                      <a
                        href="/docs/type-safety"
                        className="block select-none space-y-1 rounded-md p-3 leading-none no-underline outline-none transition-colors hover:bg-neutral-100 focus:bg-neutral-100 dark:hover:bg-neutral-800 dark:focus:bg-neutral-800"
                      >
                        <div className="text-sm font-medium leading-none">
                          Type Safety
                        </div>
                        <p className="line-clamp-2 text-sm leading-snug text-neutral-500 dark:text-neutral-400">
                          Using LogStruct with Sorbet for type-safe logging
                        </p>
                      </a>
                    </NavigationMenuLink>
                  </li>
                </ul>
              </NavigationMenuContent>
            </NavigationMenuItem>
            <NavigationMenuItem>
              <a 
                href="/api/index.html" 
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
          <SheetTrigger className="flex items-center justify-center rounded-md p-2 text-neutral-500 hover:bg-neutral-100 hover:text-neutral-900 dark:text-neutral-400 dark:hover:bg-neutral-800 dark:hover:text-neutral-50">
            <Menu className="h-6 w-6" />
            <span className="sr-only">Toggle menu</span>
          </SheetTrigger>
          <SheetContent side="right" className="w-[280px] p-0">
            <div className="flex flex-col gap-4 p-6">
              <Link href="/" className="flex items-center space-x-2">
                <span className="font-bold text-xl">LogStruct</span>
                <span className="text-xs text-neutral-500">by DocSpring</span>
              </Link>
              <div className="flex flex-col gap-3 mt-4">
                <Link 
                  href="/docs" 
                  className={cn("text-lg font-medium", pathname.startsWith('/docs') && "text-neutral-900 dark:text-neutral-50")}
                >
                  Documentation
                </Link>
                <Link 
                  href="/docs/getting-started" 
                  className="text-base text-neutral-600 dark:text-neutral-400"
                >
                  Getting Started
                </Link>
                <Link 
                  href="/docs/configuration" 
                  className="text-base text-neutral-600 dark:text-neutral-400"
                >
                  Configuration
                </Link>
                <Link 
                  href="/docs/integrations" 
                  className="text-base text-neutral-600 dark:text-neutral-400"
                >
                  Integrations
                </Link>
                <Link 
                  href="/docs/type-safety" 
                  className="text-base text-neutral-600 dark:text-neutral-400"
                >
                  Type Safety
                </Link>
                <a 
                  href="/api/index.html" 
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