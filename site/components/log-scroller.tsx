"use client";

import React, { useEffect, useRef, useState } from "react";
import { Prism as SyntaxHighlighter } from "react-syntax-highlighter";
import { atomDark } from "react-syntax-highlighter/dist/esm/styles/prism";
import useInterval from "use-interval";

// Log template entries - will be populated with dynamic data
const logTemplates = [
  { src: "puma", evt: "boot", pid: 0, lvl: "info" },
  { src: "rails", evt: "req", lvl: "info", path: "/users", method: "POST", controller: "UsersController", action: "create", status: 200, duration: 0, ip: "192.168.1.1" },
  { src: "job", evt: "start", lvl: "info", job_id: "", queue: "default", class: "ProcessJob", args: ["arg1", { _filtered: { _class: "Hash", _keys_count: 2, _keys: ["password", "confirm_password"], _bytes: 42 } }] },
  { src: "rails", evt: "req", lvl: "info", path: "/api/users", method: "GET", controller: "Api::UsersController", action: "index", status: 200, duration: 0, params: { page: 1, per_page: 10 } },
  { src: "mailer", evt: "deliver", lvl: "info", mailer: "UserMailer", action: "welcome", to: "[EMAIL:f7d9a8]", subject: "Welcome to our app!" },
  { src: "mailer", evt: "error", lvl: "error", mailer: "NotificationMailer", error: "SMTP connection failed", message: "Failed to connect to SMTP server" },
  { src: "rack", evt: "ratelimit", lvl: "warn", ip: "[IP]", path: "/login", threshold: 5, period: 60, count: 0 },
  { src: "security", evt: "ip_spoof", lvl: "error", client_ip: "[IP]", x_forwarded_for: "[IP]", path: "/api/users", method: "GET" },
  { src: "security", evt: "csrf_violation", lvl: "error", path: "/form", method: "POST", client_ip: "[IP]" },
  { src: "security", evt: "blocked_host", lvl: "error", blocked_host: "evil-site.com", path: "/", method: "GET" },
  { src: "sidekiq", evt: "process", lvl: "info", pid: 0, queues: ["default", "mailers", "active_storage"] },
  { src: "shrine", evt: "upload", lvl: "info", storage: "s3", size: 0, mime_type: "image/jpeg", file_id: "uploads/abc123.jpg" },
  { src: "activestorage", evt: "download", lvl: "info", service: "s3", key: "abc123.jpg", checksum: "sha256:abc123" },
  { src: "rails", evt: "log", lvl: "info", msg: "User 123 signed up with [EMAIL:a1b2c3]", email: { _filtered: { _class: "String", _bytes: 24, _hash: "a1b2c3" } }, phone: "[PHONE]", ssn: "[SSN]", credit_card: "[CREDIT_CARD]" },
  { src: "carrierwave", evt: "store", lvl: "info", uploader: "AvatarUploader", model: "User", file: "profile.jpg" },
];

// Generate random logs with dynamic values
const generateDynamicLogs = () => {
  return logTemplates.map(template => {
    // Create a deep copy of the template
    const log = JSON.parse(JSON.stringify(template));
    
    // Add current timestamp
    log.ts = new Date().toISOString();
    
    // Randomize numeric values
    if (log.duration !== undefined) {
      log.duration = Math.round(Math.random() * 2990 + 10) / 10; // 10-3000ms with 1 decimal place
    }
    
    if (log.pid !== undefined) {
      log.pid = Math.floor(Math.random() * 60000) + 1000;
    }
    
    if (log.size !== undefined) {
      log.size = Math.floor(Math.random() * 10000000) + 1000;
    }
    
    if (log.count !== undefined) {
      log.count = Math.floor(Math.random() * 20) + 1;
    }
    
    if (log.job_id !== undefined) {
      // Generate random alphanumeric job ID
      log.job_id = Math.random().toString(36).substring(2, 10);
    }
    
    // For requests, randomize status codes occasionally
    if (log.status !== undefined && Math.random() > 0.7) {
      const statuses = [200, 201, 204, 301, 302, 400, 401, 403, 404, 422, 500];
      log.status = statuses[Math.floor(Math.random() * statuses.length)];
    }
    
    return log;
  });
};

// Initial set of logs
const exampleLogs = generateDynamicLogs();

export function LogScroller() {
  const [logs, setLogs] = useState<string[]>([]);
  const [isPaused, setIsPaused] = useState(false);
  const scrollerRef = useRef<HTMLDivElement>(null);
  
  // Generate a random log entry
  const generateLogEntry = () => {
    // Pick a random log template
    const templateIndex = Math.floor(Math.random() * logTemplates.length);
    
    // Create a deep copy of the template
    const log = JSON.parse(JSON.stringify(logTemplates[templateIndex]));
    
    // Add current timestamp
    log.ts = new Date().toISOString();
    
    // Randomize numeric values
    if (log.duration !== undefined) {
      log.duration = Math.round(Math.random() * 2990 + 10) / 10; // 10-3000ms with 1 decimal place
    }
    
    if (log.pid !== undefined) {
      log.pid = Math.floor(Math.random() * 60000) + 1000;
    }
    
    if (log.size !== undefined) {
      log.size = Math.floor(Math.random() * 10000000) + 1000;
    }
    
    if (log.count !== undefined) {
      log.count = Math.floor(Math.random() * 20) + 1;
    }
    
    if (log.job_id !== undefined) {
      // Generate random alphanumeric job ID
      log.job_id = Math.random().toString(36).substring(2, 10);
    }
    
    // For requests, randomize status codes occasionally
    if (log.status !== undefined && Math.random() > 0.7) {
      const statuses = [200, 201, 204, 301, 302, 400, 401, 403, 404, 422, 500];
      log.status = statuses[Math.floor(Math.random() * statuses.length)];
    }
    
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
            <SyntaxHighlighter
              language="json"
              style={atomDark}
              lineProps={{style: {wordBreak: 'normal', whiteSpace: 'pre-wrap'}}}
              wrapLines
              wrapLongLines
              customStyle={{
                fontSize: "11px",
                backgroundColor: "#171717",
                padding: "12px",
                borderRadius: "6px",
              }}
            >
              {logs.join('\n\n')}
            </SyntaxHighlighter>
          </div>
        </div>
      </div>
    </div>
  );
}