"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { NavigationMenu, NavigationMenuContent, NavigationMenuItem, NavigationMenuLink, NavigationMenuList, NavigationMenuTrigger, navigationMenuTriggerStyle } from "@/components/ui/navigation-menu";
// Utility imports if needed in the future
// import { cn } from "@/lib/utils";

export function MainNav() {
  const pathname = usePathname();
  
  return (
    <div className="mr-4 flex w-full items-center justify-between">
      <Link href="/" className="flex items-center space-x-2">
        <span className="font-bold text-xl">LogStruct</span>
        <span className="text-xs text-neutral-500">by DocSpring</span>
      </Link>
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
  );
}