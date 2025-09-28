'use client';

import React, { createContext, useContext, useState } from 'react';

type FilteringCtx = {
  filtering: boolean;
  setFiltering: (enabled: boolean) => void;
};

const Ctx = createContext<FilteringCtx | null>(null);

export function FilteringProvider({ children }: { children: React.ReactNode }) {
  const [filtering, setFiltering] = useState(true);
  return (
    <Ctx.Provider value={{ filtering, setFiltering }}>{children}</Ctx.Provider>
  );
}

export function useFiltering(): FilteringCtx {
  const ctx = useContext(Ctx);
  if (!ctx)
    throw new Error('useFiltering must be used within FilteringProvider');
  return ctx;
}
