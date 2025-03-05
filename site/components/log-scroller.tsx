"use client";

import React, { useEffect, useRef, useState } from "react";
import { Prism as SyntaxHighlighter } from "react-syntax-highlighter";
import { atomDark } from "react-syntax-highlighter/dist/esm/styles/prism";
import useInterval from "use-interval";

// Sample log entries based on the examples from homepage_ideas.txt
const exampleLogs = [
  { src: "puma", evt: "boot", pid: 12345, time: "2025-03-05T12:34:56Z" },
  { path: "/cool", method: "POST", status: 200, duration: 45.2, user_id: 123 },
  { src: "job", evt: "start", job_id: "abc123", queue: "default", class: "ProcessJob" },
  { src: "rails", evt: "req", path: "/api/users", method: "GET", status: 200, duration: 12.3 },
  { src: "mailer", evt: "deliver", mailer: "UserMailer", action: "welcome", to: "[EMAIL]@example.com" },
  { src: "mailer", evt: "error", mailer: "NotificationMailer", error: "SMTP connection failed" },
  { src: "rack", evt: "ratelimit", ip: "1.2.3.4", path: "/login", threshold: 5, period: 60 },
  { src: "rails", evt: "security", sec_evt: "ip_spoof", ip: "10.0.0.1", forwarded_for: "192.168.1.1" },
  { src: "rails", evt: "security", sec_evt: "csrf_error", path: "/form", method: "POST" },
  { src: "rails", evt: "security", sec_evt: "blocked_host", host: "evil-site.com" },
  { src: "sidekiq", evt: "process", pid: 56789, queues: ["default", "mailers", "active_storage"] },
  { src: "shrine", evt: "upload", storage: "s3", size: 1024567, mime_type: "image/jpeg" },
  { src: "activestorage", evt: "download", service: "s3", key: "abc123.jpg", checksum: "sha256:abc123" },
  { user_id: 123, email: "[EMAIL HASH:f7d9a8]", password: "[FILTERED]", ssn: "[FILTERED]" },
  { src: "carrierwave", evt: "store", uploader: "AvatarUploader", model: "User", file: "profile.jpg" },
];

export function LogScroller() {
  const [logs, setLogs] = useState<string[]>([]);
  const [isPaused, setIsPaused] = useState(false);
  const scrollerRef = useRef<HTMLDivElement>(null);
  
  // Generate a random log entry
  const generateLogEntry = () => {
    const log = exampleLogs[Math.floor(Math.random() * exampleLogs.length)];
    return JSON.stringify(log, null, 0);
  };

  // Initialize with some log entries
  useEffect(() => {
    const initialLogs = Array(5)
      .fill(0)
      .map(() => generateLogEntry());
    setLogs(initialLogs);
  }, []);

  // Add a new log entry at an interval
  useInterval(() => {
    if (!isPaused) {
      setLogs((prevLogs) => {
        const newLogs = [...prevLogs, generateLogEntry()];
        // Keep only the last 15 logs
        return newLogs.slice(-15);
      });
    }
  }, 1500);

  // Scroll to the bottom when logs change
  useEffect(() => {
    if (scrollerRef.current && !isPaused) {
      scrollerRef.current.scrollTop = scrollerRef.current.scrollHeight;
    }
  }, [logs, isPaused]);

  return (
    <div
      className="w-full max-w-3xl h-[300px] bg-black rounded-lg overflow-hidden"
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
      <div className="flex items-center bg-neutral-900 px-4 py-2">
        <div className="flex space-x-2">
          <div className="w-3 h-3 rounded-full bg-red-500"></div>
          <div className="w-3 h-3 rounded-full bg-yellow-500"></div>
          <div className="w-3 h-3 rounded-full bg-green-500"></div>
        </div>
        <div className="text-white text-xs mx-auto font-mono">Rails Server Logs</div>
      </div>
      
      <div 
        ref={scrollerRef} 
        className="h-[258px] overflow-auto p-4 transition-all"
      >
        {logs.map((log, index) => (
          <div key={index} className="mb-2">
            <SyntaxHighlighter
              language="json"
              style={atomDark}
              customStyle={{
                margin: 0,
                padding: "8px",
                borderRadius: "4px",
                fontSize: "13px",
                backgroundColor: "transparent"
              }}
            >
              {log}
            </SyntaxHighlighter>
          </div>
        ))}
      </div>
    </div>
  );
}