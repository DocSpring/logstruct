'use client';

import React from 'react';
import dynamic from 'next/dynamic';

// Import dashboard examples dynamically to handle recharts client-side only rendering
const DashboardExamples = dynamic(() => import('./dashboard-examples'), {
  ssr: false,
  loading: () => (
    <div className="p-8 text-center">
      <div
        className="inline-block h-8 w-8 animate-spin rounded-full border-4 border-solid border-current border-r-transparent align-[-0.125em] motion-reduce:animate-[spin_1.5s_linear_infinite]"
        role="status"
      >
        <span className="!absolute !-m-px !h-px !w-px !overflow-hidden !whitespace-nowrap !border-0 !p-0 ![clip:rect(0,0,0,0)]">
          Loading...
        </span>
      </div>
      <p className="mt-2 text-sm text-slate-500">
        Loading visualization examples...
      </p>
    </div>
  ),
});

const DashboardClientWrapper = () => {
  return (
    <div className="mt-6 rounded-lg overflow-hidden">
      <DashboardExamples />
    </div>
  );
};

export default DashboardClientWrapper;
