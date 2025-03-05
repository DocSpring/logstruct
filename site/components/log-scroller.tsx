"use client";

import React, { useEffect, useRef, useState } from "react";
import { Prism as SyntaxHighlighter } from "react-syntax-highlighter";
import { atomDark } from "react-syntax-highlighter/dist/esm/styles/prism";
import useInterval from "use-interval";

// Sample log entries based on LogStruct's actual format
const exampleLogs = [
  { src: "puma", evt: "boot", pid: 12345, ts: "2025-03-05T12:34:56.789Z", lvl: "info" },
  { src: "rails", evt: "req", lvl: "info", ts: "2025-03-05T12:34:57.123Z", path: "/users", method: "POST", controller: "UsersController", action: "create", status: 200, duration: 45.2, ip: "192.168.1.1" },
  { src: "job", evt: "start", lvl: "info", ts: "2025-03-05T12:34:58.456Z", job_id: "abc123", queue: "default", class: "ProcessJob", args: ["arg1", { _filtered: { _class: "Hash", _keys_count: 2, _keys: ["password", "confirm_password"], _bytes: 42 } }] },
  { src: "rails", evt: "req", lvl: "info", ts: "2025-03-05T12:34:59.789Z", path: "/api/users", method: "GET", controller: "Api::UsersController", action: "index", status: 200, duration: 12.3, params: { page: 1, per_page: 10 } },
  { src: "mailer", evt: "deliver", lvl: "info", ts: "2025-03-05T12:35:00.123Z", mailer: "UserMailer", action: "welcome", to: "[EMAIL:f7d9a8]", subject: "Welcome to our app!" },
  { src: "mailer", evt: "error", lvl: "error", ts: "2025-03-05T12:35:01.456Z", mailer: "NotificationMailer", error: "SMTP connection failed", message: "Failed to connect to SMTP server" },
  { src: "rack", evt: "ratelimit", lvl: "warn", ts: "2025-03-05T12:35:02.789Z", ip: "[IP]", path: "/login", threshold: 5, period: 60, count: 6 },
  { src: "rails", evt: "security", lvl: "warn", ts: "2025-03-05T12:35:03.123Z", sec_evt: "ip_spoof", ip: "[IP]", forwarded_for: "[IP]" },
  { src: "rails", evt: "security", lvl: "warn", ts: "2025-03-05T12:35:04.456Z", sec_evt: "csrf_error", path: "/form", method: "POST" },
  { src: "rails", evt: "security", lvl: "warn", ts: "2025-03-05T12:35:05.789Z", sec_evt: "blocked_host", host: "evil-site.com" },
  { src: "sidekiq", evt: "process", lvl: "info", ts: "2025-03-05T12:35:06.123Z", pid: 56789, queues: ["default", "mailers", "active_storage"] },
  { src: "shrine", evt: "upload", lvl: "info", ts: "2025-03-05T12:35:07.456Z", storage: "s3", size: 1024567, mime_type: "image/jpeg", file_id: "uploads/abc123.jpg" },
  { src: "activestorage", evt: "download", lvl: "info", ts: "2025-03-05T12:35:08.789Z", service: "s3", key: "abc123.jpg", checksum: "sha256:abc123" },
  { src: "rails", evt: "log", lvl: "info", ts: "2025-03-05T12:35:09.123Z", msg: "User 123 signed up with [EMAIL:a1b2c3]", email: { _filtered: { _class: "String", _bytes: 24, _hash: "a1b2c3" } }, phone: "[PHONE]", ssn: "[SSN]", credit_card: "[CREDIT_CARD]" },
  { src: "carrierwave", evt: "store", lvl: "info", ts: "2025-03-05T12:35:10.456Z", uploader: "AvatarUploader", model: "User", file: "profile.jpg" },
];

export function LogScroller() {
  const [logs, setLogs] = useState<string[]>([]);
  const [isPaused, setIsPaused] = useState(false);
  const scrollerRef = useRef<HTMLDivElement>(null);
  
  // Generate a random log entry
  const generateLogEntry = () => {
    const log = exampleLogs[Math.floor(Math.random() * exampleLogs.length)];
    // Format with some spacing to make it more readable
    let jsonStr = JSON.stringify(log, null, 0);
    // Add spaces after commas, colons, and between braces
    jsonStr = jsonStr.replace(/,/g, ", ")
                     .replace(/:/g, ": ")
                     .replace(/{/g, "{ ")
                     .replace(/}/g, " }");
    return jsonStr;
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
      className="w-full max-w-[800px] h-[300px] bg-black rounded-lg overflow-hidden"
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
        <div className="w-[650px] break-words overflow-hidden">
          <div className="max-w-full">
            <pre className="text-xs bg-neutral-900 p-3 rounded font-mono text-white whitespace-pre-wrap break-words">
              {logs.join('\n\n')}
            </pre>
          </div>
        </div>
      </div>
    </div>
  );
}