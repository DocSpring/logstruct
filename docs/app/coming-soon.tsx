'use client';

export default function ComingSoon() {
  return (
    <div className="container mx-auto px-4 flex flex-col items-center justify-center min-h-[80vh] text-center">
      <h1 className="text-4xl font-bold tracking-tight sm:text-5xl md:text-6xl mb-8">
        Coming Soon
      </h1>
      <p className="text-xl text-neutral-600 dark:text-neutral-300 max-w-2xl mx-auto mb-12">
        LogStruct is a new way to add type-safe, structured JSON logging to any Rails app.
        We&apos;re currently in development and will be launching soon!
      </p>
    </div>
  );
}
