'use client';

import React, { useCallback, useEffect, useRef, useState } from 'react';
import { Prism as SyntaxHighlighter } from 'react-syntax-highlighter';
import { atomDark } from 'react-syntax-highlighter/dist/esm/styles/prism';
import useInterval from 'use-interval';
import { LogGenerator } from '../lib/log-generation/log-generator';
import { LogType } from '@/generated/logstruct';

// For generating random logs
const logGenerator = new LogGenerator();

// Puma boot log template - will always be the first log
const pumaLogTemplate = { src: 'puma', evt: 'boot', pid: 0, lvl: 'info' };

export function LogScroller() {
  const [logs, setLogs] = useState<string[]>([]);
  const [isPaused, setIsPaused] = useState(false);
  const [isVisible, setIsVisible] = useState(true);
  const [isStandalone, setIsStandalone] = useState(false);
  const [isMinimized, setIsMinimized] = useState(false);
  const [isMaximized, setIsMaximized] = useState(false);
  const scrollerRef = useRef<HTMLDivElement>(null);
  const containerRef = useRef<HTMLDivElement>(null);

  // Check if we're in standalone mode based on window width
  useEffect(() => {
    // Set initial state
    if (typeof window !== 'undefined') {
      setIsStandalone(window.innerWidth < 1280); // xl breakpoint

      // Add resize listener
      const handleResize = () => {
        setIsStandalone(window.innerWidth < 1280);
      };

      window.addEventListener('resize', handleResize);

      // Clean up
      return () => {
        window.removeEventListener('resize', handleResize);
      };
    }
  }, []);

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

  // Add a new log entry at an interval, but not when user is hovering (isPaused) unless maximized
  useInterval(() => {
    if (!isPaused || isMaximized) {
      setLogs((prevLogs) => {
        const newLogs = [...prevLogs, generateLogEntry()];
        // Keep only the last 15 logs when normal, more when maximized
        return newLogs.slice(-(isMaximized ? 30 : 15));
      });
    }
  }, 2500);

  // Scroll to the bottom when logs change
  useEffect(() => {
    if (scrollerRef.current && (!isPaused || isMaximized)) {
      scrollerRef.current.scrollTop = scrollerRef.current.scrollHeight;
    }
  }, [logs, isPaused, isMaximized]);

  // Toggle the minimized state
  const handleMinimize = () => {
    setIsMinimized(true);
    setIsMaximized(false);
  };

  // Toggle the maximized state
  const handleMaximize = () => {
    setIsMaximized(true);
    setIsMinimized(false);
  };

  // Restore the window to normal state
  const handleRestore = () => {
    setIsMinimized(false);
    setIsMaximized(false);
  };

  // If not visible, return an empty div of the same height
  if (!isVisible) {
    return <div className="w-full h-[375px]"></div>;
  }

  // We now use the isStandalone state which is controlled by the resize listener

  const baseStyle = {
    boxShadow:
      '0 10px 30px rgba(0, 0, 0, 0.2), 0 1px 3px rgba(0, 0, 0, 0.3), -5px 5px 15px rgba(0, 0, 0, 0.15)',
  };

  // Different styles based on window state and layout
  let perspectiveStyle = {};

  if (isMinimized) {
    // Minimized state - small window in bottom right
    perspectiveStyle = {
      transform: 'scale(0.25)',
      position: 'fixed' as const,
      bottom: '20px',
      right: '20px',
      width: '400px',
      zIndex: 100,
      transformOrigin: 'bottom right',
      ...baseStyle,
    };
  } else if (isMaximized) {
    // Maximized state - fixed position to cover the entire hero section
    perspectiveStyle = {
      transform: 'scale(1)',
      position: 'fixed' as const,
      top: '0',
      left: '0',
      width: '100vw',
      height: '100vh',
      marginLeft: '0',
      marginRight: '0',
      zIndex: 999,
      ...baseStyle,
      boxShadow: '0 10px 50px rgba(0, 0, 0, 0.4), 0 1px 3px rgba(0, 0, 0, 0.3)',
      borderRadius: '0',
    };
  } else {
    // Regular state - depends on standalone
    perspectiveStyle = isStandalone
      ? {
          // Straight style for standalone mode
          transform: 'scale(1)',
          marginLeft: '0',
          marginRight: '0',
          ...baseStyle,
        }
      : {
          // 3D perspective for side-by-side mode
          transform:
            'perspective(1500px) rotateX(4deg) rotateY(-8deg) rotateZ(1deg)',
          transformOrigin: 'center center',
          marginLeft: '-40px',
          marginRight: '80px',
          ...baseStyle,
        };
  }

  // Mouse over effects - only for non-minimized state
  const onMouseOverStyle = isMinimized
    ? {}
    : isStandalone
      ? {
          transform: 'scale(1.01)',
          boxShadow:
            '0 15px 35px rgba(0, 0, 0, 0.25), 0 3px 5px rgba(0, 0, 0, 0.35)',
        }
      : {
          transform:
            'perspective(1500px) rotateX(3deg) rotateY(-6deg) rotateZ(0.5deg) scale(1.01)',
          boxShadow:
            '0 15px 35px rgba(0, 0, 0, 0.25), 0 3px 5px rgba(0, 0, 0, 0.35), -8px 8px 20px rgba(0, 0, 0, 0.15)',
        };

  const onMouseOutStyle = isMinimized
    ? {}
    : isStandalone
      ? {
          transform: 'scale(1)',
          boxShadow: baseStyle.boxShadow,
        }
      : {
          transform:
            'perspective(1500px) rotateX(4deg) rotateY(-8deg) rotateZ(1deg) scale(1)',
          boxShadow: baseStyle.boxShadow,
        };

  // Adjust height based on maximized state
  const heightClass = isMaximized ? 'h-screen' : 'h-[375px]';

  return (
    <div
      ref={containerRef}
      className={`${isMaximized ? '' : 'w-full'} ${heightClass} bg-black rounded-lg overflow-hidden shadow-lg transition-all duration-300 ease-in-out`}
      style={perspectiveStyle}
      onMouseOver={(e) => {
        if (!isMinimized && !isMaximized) {
          Object.assign(e.currentTarget.style, onMouseOverStyle);
        }
      }}
      onMouseOut={(e) => {
        if (!isMinimized && !isMaximized) {
          Object.assign(e.currentTarget.style, onMouseOutStyle);
        }
      }}
      onMouseEnter={() => {
        if (!isMaximized) {
          setIsPaused(true);
        }
      }}
      onMouseLeave={() => {
        if (!isMaximized) {
          setIsPaused(false);
          // Add a small delay before resuming scrolling
          setTimeout(() => {
            if (scrollerRef.current) {
              scrollerRef.current.scrollTop = scrollerRef.current.scrollHeight;
            }
          }, 100);
        }
      }}
      onClick={() => {
        // Clicking on the minimized window restores it
        if (isMinimized) {
          handleRestore();
        }
      }}
    >
      <div
        className="relative flex items-center bg-[#393937] px-6 py-2 w-full"
        style={{
          borderBottom: '1px solid rgba(0, 0, 0, 0.3)',
          boxShadow: '0 1px 0 rgba(255, 255, 255, 0.1)',
        }}
      >
        <div className="absolute left-3 flex space-x-2">
          <div
            className="w-3 h-3 rounded-full bg-red-500 cursor-pointer hover:bg-red-400 transition-colors"
            style={{ boxShadow: '0 1px 1px rgba(0, 0, 0, 0.2)' }}
            onClick={(e) => {
              e.stopPropagation();
              setIsVisible(false);
            }}
            title="Click to close"
          ></div>
          <div
            className="w-3 h-3 rounded-full bg-yellow-500 cursor-pointer hover:bg-yellow-400 transition-colors"
            style={{ boxShadow: '0 1px 1px rgba(0, 0, 0, 0.2)' }}
            onClick={(e) => {
              e.stopPropagation();
              handleMinimize();
            }}
            title="Click to minimize"
          ></div>
          <div
            className="w-3 h-3 rounded-full bg-green-500 cursor-pointer hover:bg-green-400 transition-colors"
            style={{ boxShadow: '0 1px 1px rgba(0, 0, 0, 0.2)' }}
            onClick={(e) => {
              e.stopPropagation();
              if (isMaximized) {
                handleRestore();
              } else {
                handleMaximize();
              }
            }}
            title={isMaximized ? 'Click to restore' : 'Click to maximize'}
          ></div>
        </div>
        <div
          className="w-full text-center text-[#b5b5b3] font-extrabold text-xs font-sans"
          style={{
            textShadow: '0 1px 0 rgba(0, 0, 0, 0.3)',
            letterSpacing: '0.5px',
          }}
        >
          Rails Server Logs
        </div>
      </div>

      {/* Container with relative positioning for the scrollable content and overlay */}
      <div
        className={`relative ${isMaximized ? 'h-[calc(100vh-30px)]' : 'h-[333px]'}`}
      >
        {/* Scrollable content */}
        <div
          ref={scrollerRef}
          className="h-full flex flex-col overflow-auto px-6 py-2 bg-[#111421]"
          style={{
            backgroundImage:
              'linear-gradient(to bottom, rgba(20, 22, 36, 0.8) 0%, rgba(17, 20, 33, 1) 20%)',
            boxShadow: 'inset 0 1px 3px rgba(0, 0, 0, 0.3)',
          }}
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
                  backgroundColor: 'transparent',
                  padding: '12px',
                  borderRadius: '0px',
                  minHeight: isMaximized ? 'calc(100vh - 100px)' : '300px',
                  textShadow: '0 1px 0 rgba(0, 0, 0, 0.7)',
                  letterSpacing: '0.2px',
                }}
              >
                {logs.join('\n\n')}
              </SyntaxHighlighter>
            ) : (
              <div
                className={`w-full ${isMaximized ? 'h-[calc(100vh-100px)]' : 'h-[300px]'}`}
              ></div>
            )}
          </div>
        </div>

        {/* Reflection overlay - placed outside the scrollable div but inside the relative container */}
        <div
          className="absolute inset-0 pointer-events-none"
          style={{
            background:
              'linear-gradient(110deg, rgba(255,255,255,0.05) 0%, rgba(255,255,255,0) 45%, rgba(255,255,255,0) 85%, rgba(255,255,255,0.02) 100%)',
            zIndex: 10,
          }}
        ></div>
      </div>
    </div>
  );
}
