'use client';

import React, { useCallback, useEffect, useRef, useState } from 'react';
import { Prism as SyntaxHighlighter } from 'react-syntax-highlighter';
import { atomDark } from 'react-syntax-highlighter/dist/esm/styles/prism';
import useInterval from 'use-interval';
import { LogGenerator } from '../lib/log-generation/log-generator';
import { LogType } from '../lib/log-generation/log-types';

// For generating random logs
const logGenerator = new LogGenerator();

// Puma boot log template - will always be the first log
const pumaLogTemplate = { src: 'puma', evt: 'boot', pid: 0, lvl: 'info' };

export function LogScroller() {
  const [logs, setLogs] = useState<string[]>([]);
  const [isPaused, setIsPaused] = useState(false);
  const scrollerRef = useRef<HTMLDivElement>(null);

  // Format log for display
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const formatLogForDisplay = useCallback((log: Record<string, any>) => {
    let jsonStr = JSON.stringify(log, null, 0);
    // Add spaces after commas, colons, and between braces for better readability
    jsonStr = jsonStr
      .replace(/,/g, ', ')
      .replace(/(\w"):/g, '$1: ')
      .replace(/({)(?!})/g, '$1 ') // Add space after opening brace only if not followed by closing brace
      .replace(/(?<!{)(})/g, ' $1') // Add space before closing brace only if not preceded by opening brace
      .replace(/\{\s+\}/g, '{}'); // Remove spaces between empty braces

    return jsonStr;
  }, []);

  // Generate the Puma boot log entry (always first)
  const generatePumaBootLogEntry = useCallback(() => {
    // Use the puma boot template
    const log = JSON.parse(JSON.stringify(pumaLogTemplate));

    // Add current timestamp
    log.ts = new Date().toISOString();

    // Add pid
    log.pid = Math.floor(Math.random() * 60000) + 1000;

    return formatLogForDisplay(log);
  }, [formatLogForDisplay]);

  // Generate a random log entry (for logs after the Puma boot)
  const generateLogEntry = useCallback(() => {
    // Pick a random log type
    const logTypes = Object.values(LogType);
    const randomLogType = logTypes[Math.floor(Math.random() * logTypes.length)];

    // Generate a random log using the LogGenerator
    const log = logGenerator.generateLog(randomLogType);

    return formatLogForDisplay(log);
  }, [formatLogForDisplay]);

  // Initialize with the Puma boot log
  useEffect(() => {
    // Start with only the Puma boot log
    setLogs([generatePumaBootLogEntry()]);
  }, [generatePumaBootLogEntry]);

  // Add a new log entry at an interval, but not when user is hovering (isPaused)
  useInterval(() => {
    if (!isPaused) {
      setLogs((prevLogs) => {
        const newLogs = [...prevLogs, generateLogEntry()];
        // Keep only the last 15 logs
        return newLogs.slice(-15);
      });
    }
  }, 2500);

  // Scroll to the bottom when logs change
  useEffect(() => {
    if (scrollerRef.current && !isPaused) {
      scrollerRef.current.scrollTop = scrollerRef.current.scrollHeight;
    }
  }, [logs, isPaused]);

  return (
    <div
      className="w-full h-[375px] bg-black rounded-lg overflow-hidden"
      onMouseEnter={() => setIsPaused(true)}
      onMouseLeave={() => {
        setIsPaused(false);
        // Add a small delay before resuming scrolling
        setTimeout(() => {
          if (scrollerRef.current) {
            scrollerRef.current.scrollTop = scrollerRef.current.scrollHeight;
          }
        }, 100);
      }}
    >
      <div className="relative flex items-center bg-[#393937] px-6 py-2 w-full">
        <div className="absolute left-3 flex space-x-2">
          <div className="w-3 h-3 rounded-full bg-red-500"></div>
          <div className="w-3 h-3 rounded-full bg-yellow-500"></div>
          <div className="w-3 h-3 rounded-full bg-green-500"></div>
        </div>
        <div className="w-full text-center text-[#b5b5b3] font-extrabold text-xs font-sans">
          Rails Server Logs
        </div>
      </div>

      <div
        ref={scrollerRef}
        className="h-[333px] flex flex-col overflow-auto px-6 py-2 bg-[#111421] relative"
      >
        <div className="flex-grow w-full">
          {logs.length > 0 ? (
            <SyntaxHighlighter
              language="json"
              style={atomDark}
              lineProps={{
                style: { wordBreak: 'normal', whiteSpace: 'pre-wrap' },
              }}
              wrapLines
              wrapLongLines
              customStyle={{
                fontSize: '11px',
                backgroundColor: '#111421',
                padding: '12px',
                borderRadius: '0px',
                minHeight: '300px',
              }}
            >
              {logs.join('\n\n')}
            </SyntaxHighlighter>
          ) : (
            <div className="w-full h-[300px]"></div>
          )}
        </div>
      </div>
    </div>
  );
}
