import { Metadata } from "next";
import { Button } from "@/components/ui/button";
import Link from "next/link";

export const metadata: Metadata = {
  title: "LogStruct API Documentation",
  description: "Browse the complete API documentation for the LogStruct Ruby gem",
};

export default function APIDocRedirect() {
  return (
    <div className="container flex flex-col items-center justify-center min-h-[calc(100vh-300px)] py-16">
      <h1 className="text-3xl font-bold mb-8 text-center">API Documentation</h1>
      <p className="text-lg text-neutral-600 dark:text-neutral-400 max-w-xl text-center mb-6">
        The LogStruct API documentation shows all modules, classes and methods with their Sorbet type signatures.
      </p>
      
      <div className="grid gap-4 sm:grid-cols-2 max-w-xl">
        <Button asChild size="lg" className="w-full">
          <a href="/api/index.html" target="_blank">
            Browse API Documentation
          </a>
        </Button>
        <Button variant="outline" asChild size="lg" className="w-full">
          <Link href="/docs" className="w-full">
            Return to Guides
          </Link>
        </Button>
      </div>
      
      <p className="mt-8 text-sm text-neutral-500 dark:text-neutral-500 max-w-md text-center">
        Note: API documentation opens in a new tab and is generated with YARD and yard-sorbet.
      </p>
    </div>
  );
}